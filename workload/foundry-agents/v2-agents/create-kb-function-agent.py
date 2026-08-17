"""
Route B - Step 2: Create the Foundry agent, backed by the Knowledge Base via a
FUNCTION TOOL bridge.

Why a function tool? azure-ai-projects 2.3.0's AzureAISearchTool can only target
an *index*, not a Knowledge Base. So instead of the built-in search tool, we give
the agent a function `search_knowledge_base(query)`. At runtime OUR code fulfils
that call by invoking the KB retrieval client (see run-kb-agent-stream.py).
"""
from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient
from azure.ai.projects.models import FunctionTool, PromptAgentDefinition

# Foundry project endpoint with format: https://{your-resource-name}.services.ai.azure.com/api/projects/{your-project-name}
PROJECT_ENDPOINT = "https://aifoundry3738.services.ai.azure.com/api/projects/project3738"

# Foundry prompt agent to create with LLM model and function-tool bridge to the knowledge base
AGENT_NAME = "v2agent-rag-kb-001"
MODEL_DEPLOYMENT_NAME = "gpt-4o"

project_client = AIProjectClient(endpoint=PROJECT_ENDPOINT, credential=DefaultAzureCredential())

# Function-tool declaration the model can call. Execution happens client-side.
kb_tool = FunctionTool(
    name="search_knowledge_base",
    description=(
        "Retrieve grounded information from the NASA e-books knowledge base. "
        "Returns passages plus their source URLs to be used as citations."
    ),
    parameters={
        "type": "object",
        "properties": {
            "query": {
                "type": "string",
                "description": "The natural-language question to retrieve grounding for.",
            }
        },
        "required": ["query"],
        "additionalProperties": False,
    },
)

agent = project_client.agents.create_version(
    agent_name=AGENT_NAME,
    definition=PromptAgentDefinition(
        model=MODEL_DEPLOYMENT_NAME,
        instructions=(
            "You are a helpful assistant. To answer questions, ALWAYS call the "
            "search_knowledge_base tool first. Base your answer only on its results. "
            "For every claim, add a citation using the source_url returned by the tool, "
            "rendered as a markdown link [source_file_name](source_url)."
        ),
        tools=[kb_tool],
    ),
    description="RAG agent backed by an Azure AI Search Knowledge Base (function-tool bridge).",
)

print(f"Agent created (id: {agent.id}, name: {agent.name}, version: {agent.version})")
