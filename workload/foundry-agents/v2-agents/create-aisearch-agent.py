
from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient
from azure.ai.projects.models import (
    AzureAISearchTool,
    PromptAgentDefinition,
    AzureAISearchToolResource,
    AISearchIndexResource,
    AzureAISearchQueryType,
)

# Project endpoint with format: https://{your-resource-name}.services.ai.azure.com/api/projects/{your-project-name}
PROJECT_ENDPOINT = "https://aifoundry3738.services.ai.azure.com/api/projects/project3738" 

# Search connection and index details - find these in the Azure portal
AI_SEARCH_PROJECT_CONNECTION_ID = "aifoundry3738search"
AI_SEARCH_INDEX_NAME = "py-rag-tutorial-idx"

# Agent and model details
AGENT_NAME = "v2agent-rag-001"
MODEL_DEPLOYMENT_NAME = "gpt-4o"


# Create handle for AI Project Client
project_client = AIProjectClient(
    endpoint=PROJECT_ENDPOINT,
    credential=DefaultAzureCredential(),
)

# [START tool_declaration]
# Create an Azure AI Search tool resource (for client side reference)
tool = AzureAISearchTool(
            azure_ai_search=AzureAISearchToolResource(
                indexes=[
                    AISearchIndexResource(
                        project_connection_id=AI_SEARCH_PROJECT_CONNECTION_ID,
                        index_name=AI_SEARCH_INDEX_NAME,
                        query_type=AzureAISearchQueryType.SIMPLE,
                    ),
                ]
            )
        )
# [END tool_declaration]

# Create an agent with the Azure AI Search tool included in the definition
agent = project_client.agents.create_version(
    agent_name=AGENT_NAME,
    definition=PromptAgentDefinition(
        model=MODEL_DEPLOYMENT_NAME,
        instructions="""You are a helpful assistant. You must always provide citations for
        answers using the tool and render them as: `\u3010message_idx:search_idx\u2020source\u3011`.""",
        tools=[tool],
    ),
    description="You are a helpful agent.",
)

print(f"Agent created (id: {agent.id}, name: {agent.name}, version: {agent.version})")