# KB via MCP (Foundry IQ) — agent scripts

Connect a Foundry prompt agent to an Azure AI Search **Knowledge Base** using the
**MCP** tool. Retrieval runs **server-side** (Foundry → KB via the project's
managed identity), so the client never needs direct access to the private Search
endpoint, and citations come back automatically as response annotations.

Based on: *Connect Agents to Foundry IQ Knowledge Bases* (Microsoft Learn).
Uses the `2026-05-01-preview` Search API (preview — fine for dev).

## Files

| File | What it does |
|------|--------------|
| `kb_create_mcp_connection.py` | One-time: creates the Foundry `RemoteTool` project connection to the KB's MCP endpoint (via ARM). |
| `create-kb-mcp-agent.py` | Creates the agent with the `MCPTool` (`allowed_tools=["knowledge_base_retrieve"]`). |
| `run-kb-mcp-agent.py` | Simple single-call streaming runner; prints the answer + `url_citation` annotations. |

## Prerequisites

- An existing Knowledge Base in Azure AI Search (e.g. `py-citation-kb`).
- `azure-ai-projects>=2.0.0`, `azure-identity`, `requests`, `python-dotenv`.
- **RBAC** (or the MCP call fails server-side):
  - Project system-assigned MI → **Search Index Data Reader** on the Search service.
  - Search service system-assigned MI → **Cognitive Services User** on the project's
    parent account (needed because the KB uses an LLM for query planning).
  - You need **Foundry Project Manager** to create the connection.

## Configuration

These are read from environment variables (with sensible defaults baked into the
scripts). Set at least `PROJECT_RESOURCE_ID`:

| Variable | Example |
|----------|---------|
| `PROJECT_RESOURCE_ID` | `/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.CognitiveServices/accounts/<acct>/projects/<your-project-name>` |
| `AZURE_SEARCH_SERVICE` | `https://{your-search-service}.search.windows.net` |
| `KNOWLEDGE_BASE_NAME` | `py-citation-kb` |
| `PROJECT_CONNECTION_NAME` | `py-citation-kb-mcp-connection` |

The project endpoint, agent name, and model are set as constants near the top of
each script — edit them there if needed.

## Run order

```bash
# 0. create the knowledge base for existing Foundry IQ index
python kb_build_knowledge_base.py

# 1. one-time: create the MCP connection (hits management.azure.com)
python kb_create_mcp_connection.py

# 2. create the agent (prints its version)
python create-kb-mcp-agent.py
#    -> set AGENT_VERSION in run-kb-mcp-agent.py to that number

# 3. run it
python run-kb-mcp-agent.py
```

## Notes

- Only `knowledge_base_retrieve` is exposed by KB MCP endpoints today.
- For per-user document security, forward the user's Search token via the
  `x-ms-query-source-authorization` header using a structured input.
