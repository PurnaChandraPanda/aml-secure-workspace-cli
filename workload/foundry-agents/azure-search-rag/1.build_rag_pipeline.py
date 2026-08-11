from azure.identity import DefaultAzureCredential
from azure.identity import get_bearer_token_provider
from azure.search.documents.indexes import SearchIndexClient, SearchIndexerClient
from azure.search.documents.indexes.models import (
    SearchField,
    SearchFieldDataType,
    VectorSearch,
    HnswAlgorithmConfiguration,
    VectorSearchProfile,
    AzureOpenAIVectorizer,
    AzureOpenAIVectorizerParameters,
    SearchIndex
)

from azure.search.documents.indexes.models import (
    SearchIndexerDataContainer,
    SearchIndexerDataSourceConnection
)

from azure.search.documents.indexes.models import (
    SplitSkill,
    InputFieldMappingEntry,
    OutputFieldMappingEntry,
    AzureOpenAIEmbeddingSkill,
    EntityRecognitionSkill,
    SearchIndexerIndexProjection,
    SearchIndexerIndexProjectionSelector,
    SearchIndexerIndexProjectionsParameters,
    IndexProjectionMode,
    SearchIndexerSkillset,
    CognitiveServicesAccountKey,
    AIServicesAccountIdentity,
    SearchIndexer
)

from dotenv import load_dotenv
import os, time, json

from flask import logging

# Load environment variables from .env file
load_dotenv()

AZURE_SEARCH_SERVICE = os.getenv("AZURE_SEARCH_SERVICE")
AZURE_OPENAI_ACCOUNT = os.getenv("AZURE_OPENAI_ACCOUNT")
AZURE_OPENAI_EMBEDDING_DEPLOYMENT = os.getenv("AZURE_OPENAI_EMBEDDING_DEPLOYMENT")
AZURE_OPENAI_EMBEDDING_MODEL = os.getenv("AZURE_OPENAI_EMBEDDING_MODEL")
AZURE_STORAGE_CONNECTION = os.getenv("AZURE_STORAGE_CONNECTION")
AI_SERVICES_ACCOUNT = os.getenv("AI_SERVICES_ACCOUNT")

credential = DefaultAzureCredential()

# Initialize the SearchIndexClient, SearchIndexerClient with the endpoint and credential
_index_client = SearchIndexClient(endpoint=AZURE_SEARCH_SERVICE, credential=credential)
_indexer_client = SearchIndexerClient(endpoint=AZURE_SEARCH_SERVICE, credential=credential)

# Define the name of the search index, skillset, and data source
index_name = os.getenv("AZURE_SEARCH_INDEX")
skillset_name = "py-rag-tutorial-ss"
datasource_name = "py-rag-tutorial-ds"

def _create_search_index():
    # Create a search index
        
    fields = [
        SearchField(name="parent_id", type=SearchFieldDataType.String),  
        SearchField(name="title", type=SearchFieldDataType.String),
        SearchField(name="locations", type=SearchFieldDataType.Collection(SearchFieldDataType.String), filterable=True),
        SearchField(name="chunk_id", type=SearchFieldDataType.String, key=True, sortable=True, filterable=True, facetable=True, analyzer_name="keyword"),  
        SearchField(name="chunk", type=SearchFieldDataType.String, sortable=False, filterable=False, facetable=False),  
        SearchField(name="text_vector", type=SearchFieldDataType.Collection(SearchFieldDataType.Single), vector_search_dimensions=1024, vector_search_profile_name="myHnswProfile")
        ]  
    
    # Configure the vector search configuration  
    vector_search = VectorSearch(  
        algorithms=[  
            HnswAlgorithmConfiguration(name="myHnsw"),
        ],  
        profiles=[  
            VectorSearchProfile(  
                name="myHnswProfile",  
                algorithm_configuration_name="myHnsw",  
                vectorizer_name="myOpenAI",  
            )
        ],  
        vectorizers=[  
            AzureOpenAIVectorizer(  
                vectorizer_name="myOpenAI",  
                kind="azureOpenAI",  
                parameters=AzureOpenAIVectorizerParameters(  
                    resource_url=AZURE_OPENAI_ACCOUNT,  
                    deployment_name=AZURE_OPENAI_EMBEDDING_DEPLOYMENT,
                    model_name=AZURE_OPENAI_EMBEDDING_MODEL
                ),
            ),  
        ], 
    )  
    
    # Create the search index
    ## create_or_update_index(): will create the index if it doesn't exist, or update it if it does
    index = SearchIndex(name=index_name, fields=fields, vector_search=vector_search)  
    result = _index_client.create_or_update_index(index)
    print(f"{result.name} created")

def _create_search_datasource():
    # Create a data source for indexing (if needed)
    container = SearchIndexerDataContainer(name="nasa-ebooks-pdfs-all")

    # Managed identity auth: NO AccountKey / NO SAS
    # Format expected by Search: ResourceId=/subscriptions/.../resourceGroups/.../providers/Microsoft.Storage/storageAccounts/<name>;
    data_source_connection = SearchIndexerDataSourceConnection(
        name=datasource_name,
        type="azureblob",
        connection_string=AZURE_STORAGE_CONNECTION,
        container=container
    )
    data_source = _indexer_client.create_or_update_data_source_connection(data_source_connection)

    print(f"Data source '{data_source.name}' created or updated")

def _create_search_skillset():
    # Create a skillset   

    split_skill = SplitSkill(  
        description="Split skill to chunk documents",  
        text_split_mode="pages",  
        context="/document",  
        maximum_page_length=2000,  
        page_overlap_length=500,  
        inputs=[  
            InputFieldMappingEntry(name="text", source="/document/content"),  
        ],  
        outputs=[  
            OutputFieldMappingEntry(name="textItems", target_name="pages")  
        ],  
    )  
    
    embedding_skill = AzureOpenAIEmbeddingSkill(  
        description="Skill to generate embeddings via Azure OpenAI",  
        context="/document/pages/*",  
        resource_url=AZURE_OPENAI_ACCOUNT,  
        deployment_name=AZURE_OPENAI_EMBEDDING_DEPLOYMENT,  
        model_name=AZURE_OPENAI_EMBEDDING_MODEL,
        dimensions=1024,
        inputs=[  
            InputFieldMappingEntry(name="text", source="/document/pages/*"),  
        ],  
        outputs=[  
            OutputFieldMappingEntry(name="embedding", target_name="text_vector")  
        ],  
    )

    entity_skill = EntityRecognitionSkill(
        description="Skill to recognize entities in text",
        context="/document/pages/*",
        categories=["Location"],
        default_language_code="en",
        inputs=[
            InputFieldMappingEntry(name="text", source="/document/pages/*")
        ],
        outputs=[
            OutputFieldMappingEntry(name="locations", target_name="locations")
        ]
    )
    
    index_projections = SearchIndexerIndexProjection(  
        selectors=[  
            SearchIndexerIndexProjectionSelector(  
                target_index_name=index_name,  
                parent_key_field_name="parent_id",  
                source_context="/document/pages/*",  
                mappings=[  
                    InputFieldMappingEntry(name="chunk", source="/document/pages/*"),  
                    InputFieldMappingEntry(name="text_vector", source="/document/pages/*/text_vector"),
                    InputFieldMappingEntry(name="locations", source="/document/pages/*/locations"),  
                    InputFieldMappingEntry(name="title", source="/document/metadata_storage_name"),  
                ],  
            ),  
        ],  
        parameters=SearchIndexerIndexProjectionsParameters(  
            projection_mode=IndexProjectionMode.SKIP_INDEXING_PARENT_DOCUMENTS  
        ),  
    ) 

    # Identity omitted => using the Search service MSI
    cognitive_services_account = AIServicesAccountIdentity(subdomain_url=AI_SERVICES_ACCOUNT)

    skills = [split_skill, embedding_skill, entity_skill]

    skillset = SearchIndexerSkillset(  
        name=skillset_name,  
        description="Skillset to chunk documents and generating embeddings",  
        skills=skills,  
        index_projection=index_projections,
        cognitive_services_account=cognitive_services_account
    )
    
    _indexer_client.create_or_update_skillset(skillset)  
    print(f"{skillset.name} created")


def _print_indexer_errors(run_result, *, max_items=20):
    errors = getattr(run_result, "errors", None) or []
    if not errors:
        print("No errors in this run.")
        return

    print(f"Errors ({len(errors)}):")
    for i, e in enumerate(errors[:max_items], start=1):
        print(f"\n[{i}] status_code={getattr(e, 'status_code', None)}")
        print(f"    key: {getattr(e, 'key', None)}")
        print(f"   name: {getattr(e, 'name', None)}")
        print(f"message: {getattr(e, 'error_message', None)}")
        print(f"details: {getattr(e, 'details', None)}")
        print(f"   link: {getattr(e, 'documentation_link', None)}")

    if len(errors) > max_items:
        print(f"\n... and {len(errors) - max_items} more errors not shown")

def _create_search_indexer():
    # Create an indexer  
    indexer_name = "py-rag-tutorial-idxr"

    indexer_parameters = None

    indexer = SearchIndexer(  
        name=indexer_name,  
        description="Indexer to index documents and generate embeddings",  
        skillset_name=skillset_name,  
        target_index_name=index_name,  
        data_source_name=datasource_name,
        parameters=indexer_parameters
    )  

    # Create and run the indexer      
    _indexer_client.create_or_update_indexer(indexer)  

    print(f' {indexer_name} is created and running. Give the indexer a few minutes before running a query.')

    # Check if indexer is all ready
    while True:
        indexer_status = _indexer_client.get_indexer_status(indexer_name)

        run = indexer_status.last_result or (indexer_status.execution_history[0] if indexer_status.execution_history else None)

        
        if not run:
            print("No run info yet, waiting...")
            time.sleep(15)
            continue

        print("Top-level:", indexer_status.status, "| Run:", run.status)  # compare both

        if run.status == "success":
            print("Done")
            break

        if run.status in ("transientFailure", "persistentFailure"):
            print("Failed: ")
            _print_indexer_errors(run)
            break

        time.sleep(30)  # Wait for 30 seconds before checking the status again

def main():
    _create_search_index()
    _create_search_datasource()
    _create_search_skillset()
    _create_search_indexer()

if __name__ == "__main__":
    main()