from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from azure.search.documents import SearchClient
from azure.search.documents.models import VectorizableTextQuery
from azure.search.documents.indexes import SearchIndexClient
from azure.search.documents.indexes.models import (
    SearchField,
    SearchFieldDataType,
    VectorSearch,
    HnswAlgorithmConfiguration,
    VectorSearchProfile,
    AzureOpenAIVectorizer,
    AzureOpenAIVectorizerParameters,
    SearchIndex,
    SemanticConfiguration,
    SemanticPrioritizedFields,
    SemanticField,
    SemanticSearch,
    ScoringProfile,
    TagScoringFunction,
    TagScoringParameters
)
from openai import AzureOpenAI

from dotenv import load_dotenv
import os

# Load environment variables from .env file
load_dotenv()

AZURE_SEARCH_SERVICE = os.getenv("AZURE_SEARCH_SERVICE")
AZURE_OPENAI_ACCOUNT = os.getenv("AZURE_OPENAI_ACCOUNT")
AZURE_OPENAI_EMBEDDING_DEPLOYMENT = os.getenv("AZURE_OPENAI_EMBEDDING_DEPLOYMENT")
AZURE_OPENAI_EMBEDDING_MODEL = os.getenv("AZURE_OPENAI_EMBEDDING_MODEL")
index_name = os.getenv("AZURE_SEARCH_INDEX")

credential = DefaultAzureCredential()

token_provider = get_bearer_token_provider(credential, "https://cognitiveservices.azure.com/.default")
openai_client = AzureOpenAI(
     azure_endpoint=AZURE_OPENAI_ACCOUNT,
     azure_ad_token_provider=token_provider
 )

deployment_name = os.getenv("AZURE_OPENAI_LLM_DEPLOYMENT")

search_client = SearchClient(
     endpoint=AZURE_SEARCH_SERVICE,
     index_name=index_name,
     credential=credential
 )

def baseline_query():
    # Baseline query using only the query string without vector search or filters
    GROUNDED_PROMPT="""
    You are an AI assistant that helps users learn from the information found in the source material.
    Answer the query using only the sources provided below.
    Use bullets if the answer has multiple points.
    If the answer is longer than 3 sentences, provide a summary.
    Answer ONLY with the facts listed in the list of sources below. Cite your source when you answer the question
    If there isn't enough information below, say you don't know.
    Do not generate answers that don't use the sources below.
    Query: {query}
    Sources:\n{sources}
    """

    # Focused query on cloud formations and bodies of water
    query="Are there any cloud formations specific to oceans and large bodies of water?"
    vector_query = VectorizableTextQuery(text=query, k_nearest_neighbors=50, fields="text_vector")

    search_results = search_client.search(
        search_text=query,
        vector_queries= [vector_query],
        select=["title", "chunk", "locations"],
        top=5,
    )

    sources_formatted = "=================\n".join([f'TITLE: {document["title"]}, CONTENT: {document["chunk"]}, LOCATIONS: {document["locations"]}' for document in search_results])

    response = openai_client.chat.completions.create(
        messages=[
            {
                "role": "user",
                "content": GROUNDED_PROMPT.format(query=query, sources=sources_formatted)
            }
        ],
        model=deployment_name
    )

    print(response.choices[0].message.content)

def update_index_to_semantic():
    """
    Update the existing index to include semantic configurations and a scoring profile.
    """

    # Existing fields in the index, which must be included when updating the index
    fields = [
        SearchField(name="parent_id", type=SearchFieldDataType.String),  
        SearchField(name="title", type=SearchFieldDataType.String),
        SearchField(name="locations", type=SearchFieldDataType.Collection(SearchFieldDataType.String), filterable=True),
        SearchField(name="chunk_id", type=SearchFieldDataType.String, key=True, sortable=True, filterable=True, facetable=True, analyzer_name="keyword"),  
        SearchField(name="chunk", type=SearchFieldDataType.String, sortable=False, filterable=False, facetable=False),  
        SearchField(name="text_vector", type=SearchFieldDataType.Collection(SearchFieldDataType.Single), vector_search_dimensions=1024, vector_search_profile_name="myHnswProfile")
    ]  
  
    # Existing vector search configuration  
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
                    model_name=AZURE_OPENAI_EMBEDDING_MODEL,
                ),
            ),  
        ], 
    )

    # New semantic configuration
    semantic_config = SemanticConfiguration(
        name="my-semantic-config",
        prioritized_fields=SemanticPrioritizedFields(
            title_field=SemanticField(field_name="title"),
            keywords_fields=[SemanticField(field_name="locations")],
            content_fields=[SemanticField(field_name="chunk")]
        )
    )

    # Create the semantic settings with the configuration
    semantic_search = SemanticSearch(configurations=[semantic_config])

    # New scoring profile
    scoring_profiles = [  
        ScoringProfile(  
            name="my-scoring-profile",
            functions=[
                TagScoringFunction(  
                    field_name="locations",  
                    boost=5.0,  
                    parameters=TagScoringParameters(  
                        tags_parameter="tags",  
                    ),  
                ) 
            ]
        )
    ]


    # Create the SearchIndexClient to update the index with the new configurations
    index_client = SearchIndexClient(endpoint=AZURE_SEARCH_SERVICE, credential=credential)  

    # Update the search index with the semantic configuration and scoring profile
    index = SearchIndex(name=index_name, fields=fields, vector_search=vector_search, semantic_search=semantic_search, scoring_profiles=scoring_profiles)
    result = index_client.create_or_update_index(index)  
    print(f"{result.name} updated")  

def rag_llm_semantic():
    """
    Update the search query to use the new semantic configuration and scoring profile, which should maximize relevance of the search results and improve the LLM response.
    This is called "semantic ranking enabled hybrid search".
    """
    # Prompt is unchanged in this update
    GROUNDED_PROMPT="""
    You are an AI assistant that helps users learn from the information found in the source material.
    Answer the query using only the sources provided below.
    Use bullets if the answer has multiple points.
    If the answer is longer than 3 sentences, provide a summary.
    Answer ONLY with the facts listed in the list of sources below.
    If there isn't enough information below, say you don't know.
    Do not generate answers that don't use the sources below.
    Query: {query}
    Sources:\n{sources}
    """

    # Queries are unchanged in this update
    query="Are there any cloud formations specific to oceans and large bodies of water?"
    vector_query = VectorizableTextQuery(text=query, k_nearest_neighbors=50, fields="text_vector")

    # Add query_type semantic and semantic_configuration_name
    # Add scoring_profile and scoring_parameters
    # Note: For semantic ranker to work, go to: Azure Portal > Search service > Settings > Premium features > Enable "Free" Plan (to test); Otherwise, go for standard plan for enterprise level features.
    search_results = search_client.search(
        query_type="semantic",
        semantic_configuration_name="my-semantic-config",
        scoring_profile="my-scoring-profile",
        scoring_parameters=["tags-ocean, 'sea surface', seas, surface"],
        search_text=query,
        vector_queries= [vector_query],
        select="title, chunk, locations",
        top=5,
    )
    sources_formatted = "=================\n".join([f'TITLE: {document["title"]}, CONTENT: {document["chunk"]}, LOCATIONS: {document["locations"]}' for document in search_results])

    response = openai_client.chat.completions.create(
        messages=[
            {
                "role": "user",
                "content": GROUNDED_PROMPT.format(query=query, sources=sources_formatted)
            }
        ],
        model=deployment_name
    )

    print(response.choices[0].message.content)

def main():
    baseline_query()
    print("============")
    update_index_to_semantic()
    print("============")
    rag_llm_semantic()
    print("============")

if __name__ == "__main__":
    main()