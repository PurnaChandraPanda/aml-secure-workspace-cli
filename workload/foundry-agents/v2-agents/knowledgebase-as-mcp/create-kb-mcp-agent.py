"""
MCP Route - Step 2: Create the Foundry agent that uses the Knowledge Base via
the MCP tool (the native, supported path).

Retrieval runs server-side: Foundry calls the KB's `knowledge_base_retrieve`
MCP tool using the project connection created in kb_create_mcp_connection.py.
Citations come back as response annotations automatically.
"""
import os
from dotenv import load_dotenv
from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient
from azure.ai.projects.models import PromptAgentDefinition, MCPTool

load_dotenv()

PROJECT_ENDPOINT = os.getenv("PROJECT_ENDPOINT")
SEARCH_SERVICE_ENDPOINT = os.getenv("AZURE_SEARCH_SERVICE")
KNOWLEDGE_BASE_NAME = os.getenv("KNOWLEDGE_BASE_NAME")
PROJECT_CONNECTION_NAME = os.getenv("PROJECT_CONNECTION_NAME")

AGENT_NAME = "v2agent-rag-kbmcp-001"
MODEL_DEPLOYMENT_NAME = "gpt-4o"

MCP_ENDPOINT = (
    f"{SEARCH_SERVICE_ENDPOINT}/knowledgebases/{KNOWLEDGE_BASE_NAME}"
    f"/mcp?api-version=2026-05-01-preview"
)

INSTRUCTIONS = (
    "You are a helpful assistant that must use the knowledge base to answer all "
    "questions from the user. You must never answer from your own knowledge under "
    "any circumstances.\n"
    "Every answer must always provide annotations for using the MCP knowledge base "
    "tool and render them as: `\u3010message_idx:search_idx\u2020source_name\u3011`\n"
    'If you cannot find the answer in the provided knowledge base you must respond '
    'with "I don\'t know".'
)

project_client = AIProjectClient(endpoint=PROJECT_ENDPOINT, credential=DefaultAzureCredential())

# Azure AI Search knowledge bases expose exactly one MCP tool: knowledge_base_retrieve.
mcp_kb_tool = MCPTool(
    server_label="knowledge-base",
    server_url=MCP_ENDPOINT,
    require_approval="never",
    allowed_tools=["knowledge_base_retrieve"],
    project_connection_id=PROJECT_CONNECTION_NAME,
)

agent = project_client.agents.create_version(
    agent_name=AGENT_NAME,
    definition=PromptAgentDefinition(
        model=MODEL_DEPLOYMENT_NAME,
        instructions=INSTRUCTIONS,
        tools=[mcp_kb_tool],
    ),
    description="RAG agent backed by a Foundry IQ Knowledge Base via MCP.",
)

print(f"Agent created (id: {agent.id}, name: {agent.name}, version: {agent.version})")
