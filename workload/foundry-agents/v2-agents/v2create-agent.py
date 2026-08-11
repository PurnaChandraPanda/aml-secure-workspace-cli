import os
from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient
from azure.ai.projects.models import PromptAgentDefinition

PROJECT_ENDPOINT = "https://foundryeus00321.services.ai.azure.com/api/projects/firstProject"  # your project endpoint
# AGENT_NAME = "v2agent-using-curr1-aoai"
AGENT_NAME = "v2agent-using-ext111-aoai"
MODEL_DEPLOYMENT_NAME = "gpt-5.2-chat"
# MODEL_DEPLOYMENT_NAME = "existing31-aoai/gpt-4o-mini"


project_client = AIProjectClient(
    endpoint=PROJECT_ENDPOINT,
    credential=DefaultAzureCredential(),
)

agent = project_client.agents.create_version(
    agent_name=AGENT_NAME,
    definition=PromptAgentDefinition(
        model=MODEL_DEPLOYMENT_NAME,
        instructions="You are a helpful assistant that answers general questions",
    ),
)
print(f"Agent created (id: {agent.id}, name: {agent.name}, version: {agent.version})")