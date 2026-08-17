"""
MCP Route - Step 1: Create the Foundry project 'RemoteTool' connection that
targets the Knowledge Base's MCP endpoint.

This is created via the Azure Resource Manager (management.azure.com) API, using
the project's managed identity to authenticate to Azure AI Search at query time.
After this, an agent can reference the KB through the MCP tool (see
create-kb-mcp-agent.py) and retrieval runs SERVER-SIDE (no client access to the
private Search endpoint required).

Prerequisite:
  - Project has a system-assigned managed identity.
  - Project MI  -> 'Search Index Data Reader' on the Search service.
  - Search MI   -> 'Cognitive Services User' on the project's parent resource
                    (required because the KB specifies an LLM for query planning).
  - You have 'Foundry Project Manager' to create the connection.

Set PROJECT_RESOURCE_ID in the environment.
"""
import os
import requests
from dotenv import load_dotenv
from azure.identity import DefaultAzureCredential

load_dotenv()

# ARM resource id of the Foundry PROJECT. Must be the CognitiveServices namespace:
#   /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.CognitiveServices/accounts/<acct>/projects/<proj>
PROJECT_RESOURCE_ID = os.getenv("PROJECT_RESOURCE_ID")

SEARCH_SERVICE_ENDPOINT = os.getenv("AZURE_SEARCH_SERVICE")
KNOWLEDGE_BASE_NAME = os.getenv("KNOWLEDGE_BASE_NAME")
PROJECT_CONNECTION_NAME = os.getenv("PROJECT_CONNECTION_NAME")

# The KB MCP endpoint that enables the agent<->KB connection.
MCP_ENDPOINT = (
    f"{SEARCH_SERVICE_ENDPOINT}/knowledgebases/{KNOWLEDGE_BASE_NAME}"
    f"/mcp?api-version=2026-05-01-preview"
)

credential = DefaultAzureCredential()
mgmt_token = credential.get_token("https://management.azure.com/.default").token

url = (
    f"https://management.azure.com{PROJECT_RESOURCE_ID}"
    f"/connections/{PROJECT_CONNECTION_NAME}?api-version=2025-10-01-preview"
)

body = {
    "name": PROJECT_CONNECTION_NAME,
    "type": "Microsoft.MachineLearningServices/workspaces/connections",
    "properties": {
        "authType": "ProjectManagedIdentity",
        "category": "RemoteTool",
        "target": MCP_ENDPOINT,
        "isSharedToAll": True,
        "audience": "https://search.azure.com/",
        "metadata": {"ApiType": "Azure"},
    },
}

resp = requests.put(
    url,
    headers={"Authorization": f"Bearer {mgmt_token}", "Content-Type": "application/json"},
    json=body,
    timeout=60,
)
resp.raise_for_status()
print(f"Connection '{PROJECT_CONNECTION_NAME}' created or updated successfully.")
print("MCP endpoint:", MCP_ENDPOINT)
