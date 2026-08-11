
import os
from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient

# Project endpoint with format: https://{your-resource-name}.services.ai.azure.com/api/projects/{your-project-name}
PROJECT_ENDPOINT = "https://aifoundry3738.services.ai.azure.com/api/projects/project3738"  

with DefaultAzureCredential() as cred, AIProjectClient(endpoint=PROJECT_ENDPOINT, credential=cred) as project_client:

    # Name of existing AOAI deployment
    model = "gpt-4o"

    # Create agent
    agent = project_client.agents.create_agent(
        model=model,
        name="agent-test1",
        instructions="You are a helpful assistant."
    )
    
    print("Agent ID:", agent.id)
