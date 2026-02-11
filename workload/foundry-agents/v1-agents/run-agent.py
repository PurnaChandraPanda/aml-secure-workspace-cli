import time
import json

from azure.ai.agents import AgentsClient
from azure.ai.agents.models import MessageTextContent, ListSortOrder
from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential
from azure.ai.agents.models import (
    ListSortOrder
)

# Project endpoint with format: https://{your-resource-name}.services.ai.azure.com/api/projects/{your-project-name}
PROJECT_ENDPOINT = "https://aifoundry1231.services.ai.azure.com/api/projects/project1231"  

def main(user_input: str):
    # Create the AI Project Client
    project_client = AIProjectClient(
        endpoint=PROJECT_ENDPOINT,
        credential=DefaultAzureCredential()
    )

    # Retrieve the agent definition based on the `agent_id`
    agent = project_client.agents.get_agent(
                        agent_id="asst_9LKtTdIlmn4QBuNGAdJS4uI0"  
                        )
    print(f"Retrieved agent, agent ID: {agent.id}")
    print(f"Agent model: {getattr(agent, 'model', None)}")

    # Create a thread for the agent to run in
    thread = project_client.agents.threads.create()
    print(f"Created thread, thread ID: {thread.id}")

    # Create a message from the user to start the interaction
    message = project_client.agents.messages.create(
        thread_id=thread.id, role="user", content=user_input,
        )
    print(f"Created message, message ID: {message.id}")

    # Create a run for the agent with the created thread
    run = project_client.agents.runs.create(
            thread_id=thread.id, 
            agent_id=agent.id,
            )

    # Poll the run as long as run status is queued or in progress
    while run.status in ["queued", "in_progress", "requires_action"]:
        # Wait for a second
        time.sleep(1)
        run = project_client.agents.runs.get(thread_id=thread.id, run_id=run.id)
        print(f"Run status: {run.status}")

    if run.status == "failed":
        print(f"Run error: {run.last_error}")

    # Fetch and print run steps and messages
    run_steps = project_client.agents.run_steps.list(thread_id=thread.id, run_id=run.id)
    for step in run_steps:
        print(f"Run step: {step.id}, status: {step.status}, type: {step.type}")
        if step.type == "tool_calls":
            print(f"Tool call details:")
            for tool_call in step.step_details.tool_calls:
                print(json.dumps(tool_call.as_dict(), indent=2))

    # Fetch and print all messages in the thread
    messages = project_client.agents.messages.list(thread_id=thread.id, order=ListSortOrder.ASCENDING)
    for data_point in messages:
        last_message_content = data_point.content[-1]
        if isinstance(last_message_content, MessageTextContent):
            print(f"{data_point.role}: {last_message_content.text.value}")


if __name__ == "__main__":
    print("Supply the prompt message for agent interaction: ")
    _input = input()
    main(_input)