import os
from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient

# Project endpoint with format: https://{your-resource-name}.services.ai.azure.com/api/projects/{your-project-name}
PROJECT_ENDPOINT = "https://aifoundry3738.services.ai.azure.com/api/projects/project3738"
# PROJECT_ENDPOINT = "https://foundryeus00321.services.ai.azure.com/api/projects/firstProject"

# Agent details
# AGENT_NAME = "v2agent-rag-001"
AGENT_NAME = "v2agent-rag-filesearch4"
AGENT_VERSION = "1"

project_client = AIProjectClient(
    endpoint=PROJECT_ENDPOINT,
    credential=DefaultAzureCredential(),
)

# Get openai client from project client
openai_client = project_client.get_openai_client()

def main(user_input: str):
    # Optional Step: Create a conversation to use with the agent
    conversation = openai_client.conversations.create()
    print(f"Created conversation (id: {conversation.id})")

    # Chat with the agent to answer questions
    response = openai_client.responses.create(
        conversation=conversation.id, #Optional conversation context for multi-turn
        extra_body={"agent_reference": {"name": AGENT_NAME, "version": AGENT_VERSION, "type": "agent_reference"}},
        input=user_input,
    )
    print(f"Response output: {response.output_text}")

if __name__ == "__main__":
    # user_input = "what is the NASA earth book about"
    user_input = "Tell me about Contoso products"
    main(user_input)