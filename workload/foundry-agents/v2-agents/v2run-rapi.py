import os
from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient

PROJECT_ENDPOINT = "https://aifoundry3385.services.ai.azure.com/api/projects/project3385"  # your project endpoint

MODEL_DEPLOYMENT_NAME = "existing31-aoai/gpt-4o-mini"
# MODEL_DEPLOYMENT_NAME = "gpt-4o-mini"

# import logging
# import sys
# logging.basicConfig(stream=sys.stdout, level=logging.DEBUG)

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