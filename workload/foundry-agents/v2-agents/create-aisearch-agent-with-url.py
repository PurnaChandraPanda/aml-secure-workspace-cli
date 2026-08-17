"""
Step 2: Create the agent version pointing at the Foundry Index asset (which
carries the url_field=source_url mapping) instead of the raw connection.

The agent's search citations will then include source_url as annotation.url.
Run register-search-index-asset.py first to create the asset.
"""
from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient
from azure.ai.projects.models import (
    AzureAISearchTool,
    PromptAgentDefinition,
    AzureAISearchToolResource,
    AISearchIndexResource,
    AzureAISearchQueryType,
)

PROJECT_ENDPOINT = "https://aifoundry3738.services.ai.azure.com/api/projects/project3738"

# index asset id format: <name>/versions/<version>
INDEX_ASSET_ID = "py-citation-rag-idx-asset/versions/1"

AGENT_NAME = "v2agent-rag-001"
MODEL_DEPLOYMENT_NAME = "gpt-4o"

project_client = AIProjectClient(
    endpoint=PROJECT_ENDPOINT,
    credential=DefaultAzureCredential(),
)

tool = AzureAISearchTool(
    azure_ai_search=AzureAISearchToolResource(
        indexes=[
            AISearchIndexResource(
                index_asset_id=INDEX_ASSET_ID,
                query_type=AzureAISearchQueryType.SIMPLE,
                top_k=5,
            ),
        ]
    )
)

agent = project_client.agents.create_version(
    agent_name=AGENT_NAME,
    definition=PromptAgentDefinition(
        model=MODEL_DEPLOYMENT_NAME,
        instructions=(
            "You are a helpful assistant. You must always provide citations for "
            "answers using the tool and render them as: "
            "`\u3010message_idx:search_idx\u2020source\u3011`."
        ),
        tools=[tool],
    ),
    description="RAG agent that cites source_url from the search index.",
)

print(f"Agent created (id: {agent.id}, name: {agent.name}, version: {agent.version})")
