"""
Step 0: Build the Azure AI Search Knowledge Base (agentic retrieval)
on top of the EXISTING index, so we can back a Foundry agent with it.

This does three things (idempotent):
  1. Ensure the index has a semantic configuration (agentic retrieval uses a
     semantic intent, which requires semantic ranking on the index).
  2. Create a SearchIndexKnowledgeSource pointing at the existing index, and
     ask it to surface source_url/title/source_file_name as reference data.
  3. Create a KnowledgeBase that references that source + an Azure OpenAI chat
     model for query planning.

NETWORK: talks DIRECTLY to the Azure AI Search service endpoint
(https://<svc>.search.windows.net).

Requires: azure-search-documents (with knowledgebases), python-dotenv.
"""

import os
from dotenv import load_dotenv
from azure.identity import DefaultAzureCredential
from azure.search.documents.indexes import SearchIndexClient
from azure.search.documents.indexes.models import (
    SemanticConfiguration,
    SemanticSearch,
    SemanticPrioritizedFields,
    SemanticField,
    SearchIndexKnowledgeSource,
    SearchIndexKnowledgeSourceParameters,
    SearchIndexFieldReference,
    KnowledgeBase,
    KnowledgeSourceReference,
    KnowledgeBaseAzureOpenAIModel,
    AzureOpenAIVectorizerParameters,
)

load_dotenv()

# Existing search service, index name
AZURE_SEARCH_SERVICE = os.getenv("AZURE_SEARCH_SERVICE")
INDEX_NAME = os.getenv("INDEX_NAME")

# Existing foundry openai endpoint and deployment name (must be a chat model)
AZURE_OPENAI_ACCOUNT = os.getenv("AZURE_OPENAI_ENDPOINT")
AZURE_OPENAI_LLM_DEPLOYMENT = "gpt-4o"

SEMANTIC_CONFIG_NAME = os.getenv("SEMANTIC_CONFIG_NAME")
KNOWLEDGE_SOURCE_NAME = os.getenv("KNOWLEDGE_SOURCE_NAME")
KNOWLEDGE_BASE_NAME = os.getenv("KNOWLEDGE_BASE_NAME")

credential = DefaultAzureCredential()
index_client = SearchIndexClient(endpoint=AZURE_SEARCH_SERVICE, credential=credential)


def ensure_semantic_config():
    index = index_client.get_index(INDEX_NAME)
    existing = []
    if index.semantic_search and index.semantic_search.configurations:
        existing = [c.name for c in index.semantic_search.configurations]
    if SEMANTIC_CONFIG_NAME in existing:
        print(f"Semantic config '{SEMANTIC_CONFIG_NAME}' already present.")
        return

    sem_config = SemanticConfiguration(
        name=SEMANTIC_CONFIG_NAME,
        prioritized_fields=SemanticPrioritizedFields(
            title_field=SemanticField(field_name="title"),
            content_fields=[SemanticField(field_name="chunk")],
        ),
    )
    # Preserve any pre-existing configs, add ours.
    configs = list(index.semantic_search.configurations) if index.semantic_search else []
    configs.append(sem_config)
    index.semantic_search = SemanticSearch(configurations=configs)
    index_client.create_or_update_index(index)
    print(f"Added semantic config '{SEMANTIC_CONFIG_NAME}' to index '{INDEX_NAME}'.")


def create_knowledge_source():
    ks = SearchIndexKnowledgeSource(
        name=KNOWLEDGE_SOURCE_NAME,
        description="Knowledge source over the NASA e-books citation index.",
        search_index_parameters=SearchIndexKnowledgeSourceParameters(
            search_index_name=INDEX_NAME,
            semantic_configuration_name=SEMANTIC_CONFIG_NAME,
            # Surface these fields in each reference's source_data (this is how
            # we get source_url back for citations on the KB route).
            source_data_fields=[
                SearchIndexFieldReference(name="chunk"),
                SearchIndexFieldReference(name="title"),
                SearchIndexFieldReference(name="source_url"),
                SearchIndexFieldReference(name="source_file_name"),
            ],
        ),
    )
    index_client.create_or_update_knowledge_source(ks)
    print(f"Knowledge source '{KNOWLEDGE_SOURCE_NAME}' created/updated.")


def create_knowledge_base():
    kb = KnowledgeBase(
        name=KNOWLEDGE_BASE_NAME,
        description="Knowledge base for the NASA e-books RAG agent.",
        knowledge_sources=[KnowledgeSourceReference(name=KNOWLEDGE_SOURCE_NAME)],
        models=[
            KnowledgeBaseAzureOpenAIModel(
                azure_open_ai_parameters=AzureOpenAIVectorizerParameters(
                    resource_url=AZURE_OPENAI_ACCOUNT,
                    deployment_name=AZURE_OPENAI_LLM_DEPLOYMENT,
                    model_name=AZURE_OPENAI_LLM_DEPLOYMENT,
                )
            )
        ],
    )
    index_client.create_or_update_knowledge_base(kb)
    print(f"Knowledge base '{KNOWLEDGE_BASE_NAME}' created/updated.")


def main():
    ensure_semantic_config()
    create_knowledge_source()
    create_knowledge_base()
    print("\nDone. Knowledge base ready:", KNOWLEDGE_BASE_NAME)


if __name__ == "__main__":
    main()
