## Foundry standard agent: existing aoai
- With 15b tf template modified, 
1) added connection for existing aoai resource (this aoai resource has PE in foundry PE subnet; PNA disabled)
2) re-create caphost for project with the existing aoai connection under `aiServicesConnections`.

- As Standard Foundry account exists in this case, project caphost exists. By design, caphost resources are immutable.
- So, need to drop the project caphost. Then, create the project caphost again with `aiServicesConnections` param set for existing aoai connection.

- From the caller side, DNS side points need to be taken care for foundry and its child services.

- Caphost for project output indicates that `aiServicesConnections` is set correctly to the existing aoai resource arm id (note: aoai and foundry are in same location and subscription)

```
{
  "value": [
    {
      "id": "/subscriptions/6977-----------------f6532103/resourceGroups/rg-stdfoundry3/providers/Microsoft.CognitiveServices/accounts/aifoundry3385/projects/project3385/capabilityHosts/caphostproj",
      "name": "caphostproj",
      "properties": {
        "aiServicesConnections": [
          "existing31-aoai"
        ],
        "capabilityHostKind": "Agents",
        "customerSubnet": null,
        "description": null,
        "properties": null,
        "provisioningState": "Succeeded",
        "storageConnections": [
          "aifoundry3385storage"
        ],
        "tags": null,
        "threadStorageConnections": [
          "aifoundry3385cosmosdb"
        ],
        "vectorStoreConnections": [
          "aifoundry3385search"
        ]
      },
      "systemData": {
        "createdAt": "2026-01-25T16:16:27.7674828+00:00",
        "lastModifiedAt": "2026-01-25T16:19:03.1003742+00:00"
      },
      "type": "Microsoft.CognitiveServices/accounts/projects/capabilityHosts"
    }
  ]
}
```

- As project caphost is updated with aiServicesConnections, the openai deployments of that specific existing resource can only be used in agent service.
- As a side note, if both existing resource and foundry resource deployments use are needed, then follow APIM deployments route to make such models accessible from single point - from agent service.

- Created a gpt-4o-mini deployment in current ai foundry
- The agent could be created and interacted fine as well in v1 sdk.
- For v2 sdk, implementation is not ready how to leverage in code - agent service side.

## v1 sdk run

- The code snippets are in [foundry-agents](../../../workload/foundry-agents/readme.md).

- Create agent

```python
    # Name of existing AOAI deployment
    model = "gpt-4.1-mini"

    # Create agent
    agent = project_client.agents.create_agent(
        model=model,
        name="agent-using-ext2-aoai",
        instructions="You are a helpful assistant."
    )
    
```

```
PS D:\workload\foundry-agents\v1-agents> python .\create-agent.py    
Agent ID: asst_Javi4MDxmYxRT6NlloZHlAra
```

- Run the agent

```python
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
```

```
PS D:\workload\foundry-agents\v1-agents> python .\run-agent.py
Supply the prompt message for agent interaction: 
hi there
Retrieved agent, agent ID: asst_Javi4MDxmYxRT6NlloZHlAra
Agent model: gpt-4o-mini
Created thread, thread ID: thread_YbeXSyLMOXVVCS48eFvbIfaz
Created message, message ID: msg_YVqQCyxqeWzgwWblE5E65jcD
Run status: in_progress
Run status: completed
Run step: step_Tv2h6rxS3aVQbXuePqB0n1Ix, status: completed, type: message_creation
user: hi there
assistant: Hello! How can I assist you today?
```


