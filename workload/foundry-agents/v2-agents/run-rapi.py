import os
from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient

# Project endpoint with format: https://{your-resource-name}.services.ai.azure.com/api/projects/{your-project-name}
PROJECT_ENDPOINT = "https://aifoundry3385.services.ai.azure.com/api/projects/project3385"

MODEL_DEPLOYMENT_NAME = "gpt-4o-mini"

project_client = AIProjectClient(
    endpoint=PROJECT_ENDPOINT,
    credential=DefaultAzureCredential(),
)

openai_client = project_client.get_openai_client()

response = openai_client.responses.create(
    model=MODEL_DEPLOYMENT_NAME,
    input="What is the size of France in square miles?",
)
print(f"Response output: {response.output_text}")