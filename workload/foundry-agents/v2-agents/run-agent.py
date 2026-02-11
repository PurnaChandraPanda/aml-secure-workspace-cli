import os
from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient

# Project endpoint with format: https://{your-resource-name}.services.ai.azure.com/api/projects/{your-project-name}
PROJECT_ENDPOINT = "https://aifoundry3385.services.ai.azure.com/api/projects/project3385"

AGENT_NAME = "v2agent-using-ext1-aoai"

project_client = AIProjectClient(
    endpoint=PROJECT_ENDPOINT,
    credential=DefaultAzureCredential(),
)

agent_name = AGENT_NAME
openai_client = project_client.get_openai_client()

# Optional Step: Create a conversation to use with the agent
conversation = openai_client.conversations.create()
print(f"Created conversation (id: {conversation.id})")

# Chat with the agent to answer questions
response = openai_client.responses.create(
    conversation=conversation.id, #Optional conversation context for multi-turn
    extra_body={"agent": {"name": agent_name, "type": "agent_reference"}},
    input="What is the size of France in square miles?",
)
print(f"Response output: {response.output_text}")

# Optional Step: Ask a follow-up question in the same conversation
response = openai_client.responses.create(
    conversation=conversation.id,
    extra_body={"agent": {"name": agent_name, "type": "agent_reference"}},
    input="And what is the capital city?",
)
print(f"Response output: {response.output_text}")