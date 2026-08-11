import os
import time

from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient
from azure.ai.projects.models import PromptAgentDefinition, FileSearchTool

# Project endpoint with format: https://{your-resource-name}.services.ai.azure.com/api/projects/{your-project-name}
PROJECT_ENDPOINT = "https://aifoundry3738.services.ai.azure.com/api/projects/project3738"

# Agent and model details
AGENT_NAME = "v2agent-rag-filesearch4"
MODEL_DEPLOYMENT_NAME = "gpt-4o"


# Create handle for AI Project Client
project_client = AIProjectClient(
    endpoint=PROJECT_ENDPOINT,
    credential=DefaultAzureCredential(),
)

# Get openai client from project client
openai_client = project_client.get_openai_client()

# [START tool_declaration]
# Create vector store for file search
vector_store = openai_client.vector_stores.create(name="ProductInfoStore")
print(f"Vector store created (id: {vector_store.id})")

# Load the file to be indexed for search
asset_file_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "../assets/product_info.md"))

# Upload file to vector store
file = openai_client.vector_stores.files.upload_and_poll(
    vector_store_id=vector_store.id, file=open(asset_file_path, "rb")
)
print(f"File uploaded to vector store (id: {file.id})")
tool = FileSearchTool(vector_store_ids=[vector_store.id])

# Poll for vector store to be ready for search after file upload
while True:
    vector_store = openai_client.vector_stores.retrieve(vector_store.id)

    if vector_store.status != "completed":
        print(f"Still processing: status={vector_store.status}")
    elif vector_store.file_counts.failed > 0:
        raise RuntimeError(
            f"Vector store completed with failures: "
            f"completed={vector_store.file_counts.completed}, "
            f"failed={vector_store.file_counts.failed}, "
            f"in_progress={vector_store.file_counts.in_progress}"
        )
    elif vector_store.file_counts.completed == 0:
        raise RuntimeError("Vector store completed, but no files were successfully indexed.")
    else:
        print("Vector store is fully ready for search.")
        break
    time.sleep(5)

# [END tool_declaration]

# Create an agent with the Azure AI Search tool included in the definition
agent = project_client.agents.create_version(
    agent_name=AGENT_NAME,
    definition=PromptAgentDefinition(
        model=MODEL_DEPLOYMENT_NAME,
        instructions="You are a helpful assistant that can search through product information.",
        tools=[tool],
    ),
    description="File search agent for product information queries.",
)

print(f"Agent created (id: {agent.id}, name: {agent.name}, version: {agent.version})")