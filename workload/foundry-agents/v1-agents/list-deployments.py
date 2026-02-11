
import os
from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient

# Project endpoint with format: https://{your-resource-name}.services.ai.azure.com/api/projects/{your-project-name}
PROJECT_ENDPOINT = "https://aifoundry3385.services.ai.azure.com/api/projects/project3385"

with DefaultAzureCredential() as cred, AIProjectClient(endpoint=PROJECT_ENDPOINT, credential=cred) as project_client:

    for c in project_client.connections.list():
        print("connection:", c.name, "type:", getattr(c, "type", None))

    for d in project_client.deployments.list():
        # d.connection_name tells you where it comes from (project vs a connected resource)
        print("deployment:", d.name)
        print("  model:", getattr(d, "model_name", None), getattr(d, "model_version", None))
        print("  connection_name:", getattr(d, "connection_name", None))
        print("---")

    os.environ["OPENAI_API_VERSION"] = "2024-06-01-preview"
    aoai_client = project_client.get_openai_client(connection_name="existing31-aoai")
    print("Got AOAI client via connection")


