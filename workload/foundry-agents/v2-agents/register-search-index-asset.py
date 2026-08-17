"""
Step 1: Register (or update) an Azure AI Search index as a Foundry Index asset
with a FieldMapping so that `source_url` is surfaced as the citation URL.

Run once (re-run to update). Reference the printed "name:version" from the
agent creation script via AISearchIndexResource(index_asset_id=...).
"""
from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient
from azure.ai.projects.models import AzureAISearchIndex, FieldMapping

# Project endpoint: https://{resource}.services.ai.azure.com/api/projects/{project}
PROJECT_ENDPOINT = "https://aifoundry3738.services.ai.azure.com/api/projects/project3738"

# The AI Search connection registered in the project, and the real index name.
AI_SEARCH_CONNECTION_NAME = "aifoundry3738search"
AI_SEARCH_INDEX_NAME = "py-citation-rag-tutorial-idx"

# The Foundry index-asset identity, you will reference from the agent tool.
INDEX_ASSET_NAME = "py-citation-rag-idx-asset"
INDEX_ASSET_VERSION = "1"

project_client = AIProjectClient(
    endpoint=PROJECT_ENDPOINT,
    credential=DefaultAzureCredential(),
)

field_mapping = FieldMapping(
    content_fields=["chunk"],          # text chunk shown to the model
    url_field="source_url",            # <-- surfaces source_url as the citation URL
    title_field="title",
    filepath_field="source_file_name",
    vector_fields=["text_vector"],
    metadata_fields=["locations"],
)

index_asset = project_client.indexes.create_or_update(
    name=INDEX_ASSET_NAME,
    version=INDEX_ASSET_VERSION,
    index=AzureAISearchIndex(
        connection_name=AI_SEARCH_CONNECTION_NAME,
        index_name=AI_SEARCH_INDEX_NAME,
        field_mapping=field_mapping,
    ),
)

print("Index asset registered:")
print(f"  name    : {index_asset.name}")
print(f"  version : {index_asset.version}")
print(f"  ref     : {index_asset.name}:{index_asset.version}")
print("Use this as AISearchIndexResource(index_asset_id=...) in the agent tool.")
