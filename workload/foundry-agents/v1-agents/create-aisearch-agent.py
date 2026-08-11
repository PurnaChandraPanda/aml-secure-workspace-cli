
import os
from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient
from azure.ai.agents.models import AzureAISearchTool, AzureAISearchQueryType
from azure.ai.projects.models import ConnectionType


# Project endpoint with format: https://{your-resource-name}.services.ai.azure.com/api/projects/{your-project-name}
PROJECT_ENDPOINT = "https://aifoundry3738.services.ai.azure.com/api/projects/project3738"  

# Find the index name on the Search Management > Indexes page of your Azure AI Search service
index_name = "py-rag-tutorial-idx"

with DefaultAzureCredential() as cred, AIProjectClient(endpoint=PROJECT_ENDPOINT, credential=cred) as project_client:

    # Name of existing AOAI deployment
    model = "gpt-4o"

    # Define the Azure AI Search connection ID and index name
    azure_ai_conn_id = project_client.connections.get_default(ConnectionType.AZURE_AI_SEARCH).id

    # Initialize the Azure AI Search tool
    ai_search = AzureAISearchTool(
        index_connection_id=azure_ai_conn_id,
        index_name=index_name,
        query_type=AzureAISearchQueryType.SIMPLE,  # Use SIMPLE query type
        top_k=3,  # Retrieve the top 3 results
        filter="",  # Optional filter for search results
    )

    # Create agent
    agent = project_client.agents.create_agent(
        model=model,
        name="agent-test3",
        instructions="You are a helpful assistant.",
        tools=ai_search.definitions,
        tool_resources=ai_search.resources
    )
    
    print("Agent ID:", agent.id)
