# KB via function-tool bridge — agent scripts

Back a Foundry prompt agent with an Azure AI Search **Knowledge Base** using a
**function-tool bridge**. The agent is given a function `search_knowledge_base(query)`;
at runtime **our code** fulfils that call by querying the KB retrieval client and
returns passages + `source_url` citations back to the model.

Why this route? `azure-ai-projects` 2.3.0's built-in search tool can only target an
*index*, not a Knowledge Base. The function tool is the bridge to agentic KB
retrieval while keeping full control over how references become citations.

> Compare with the sibling `knowledgebase-as-mcp/` folder, where retrieval runs
> **server-side** and needs no client access to Search. This function-tool route
> runs retrieval **client-side**, so it must run from inside the vnet.

## Files

| File | What it does |
|------|--------------|
| `kb_build_knowledge_base.py` | One-time: ensures a semantic config on the existing index, then creates the `KnowledgeSource` + `KnowledgeBase` (surfaces `source_url`/title/file name as reference data). |
| `create-kb-function-agent.py` | Creates the agent with the `search_knowledge_base` function tool. Prints the agent version. |
| `run-kb-agent-stream.py` | Runs the function-calling loop: streams the agent, fulfils each `search_knowledge_base` call via the KB retrieval client, returns citations, streams the grounded answer. |

## Prerequisites

- An existing Azure AI Search index (e.g. `py-citation-rag-tutorial-idx`) with a
  `source_url` field.
- `azure-ai-projects>=2.0.0`, `azure-search-documents` (with `knowledgebases`),
  `azure-identity`, `python-dotenv`.
- **Network:** `kb_build_knowledge_base.py` and `run-kb-agent-stream.py` talk
  **directly** to the private Search endpoint (`*.search.windows.net`, `10.0.0.13`),
  so run them **from inside the vnet**. `create-kb-function-agent.py` only hits the
  Foundry project endpoint and can run from anywhere with access.
- **RBAC:** your identity needs data-plane access to the Search service
  (e.g. **Search Index Data Contributor** to build the KB, **Search Index Data
  Reader** to query it), and the Search service MI needs **Cognitive Services User**
  on the Azure OpenAI account (the KB uses an LLM for query planning).

## Configuration

Key values are set as **constants near the top of each script** — edit them there:

| Setting | Where | Example |
|---------|-------|---------|
| `PROJECT_ENDPOINT` | all 3 | `https://{resource}.services.ai.azure.com/api/projects/{project}` |
| `AZURE_SEARCH_SERVICE` | build + run | `https://{your-search-service}.search.windows.net` |
| `INDEX_NAME` | build | `py-citation-rag-tutorial-idx` |
| `AZURE_OPENAI_ACCOUNT` / `AZURE_OPENAI_LLM_DEPLOYMENT` | build | `https://{resource}.openai.azure.com/` / `gpt-4o` |
| `KNOWLEDGE_BASE_NAME` / `KNOWLEDGE_SOURCE_NAME` | build + run | `py-citation-kb` / `py-citation-ks` |
| `AGENT_NAME` / `AGENT_VERSION` | create + run | `v2agent-rag-kb-001` / `1` |
| `TOP_K_REFERENCES` | run | `5` (rank by reranker score, dedupe by URL, cap) |

## Run order

- To work with search service, from client side, make sure `azure-search-documents==12.0.0` (or latest) is installed.
- Use existing AI Search index with a mix of semantic configuration to create knowledge base.

```bash
# 1. create semantic config + KnowledgeSource + KnowledgeBase (from the vnet)
python kb_build_knowledge_base.py

# 2. create the agent (prints its version)
python create-kb-function-agent.py
#    -> set AGENT_VERSION in run-kb-agent-stream.py to that number

# 3. run the KB-backed agent (from the vnet)
python run-kb-agent-stream.py
```

## Notes

- Agentic retrieval uses a **semantic intent**, which requires a semantic
  configuration on the index — `kb_build_knowledge_base.py` adds one idempotently.
- Citations come from each reference's `source_data` (`include_reference_source_data=True`),
  which is why the `KnowledgeSource` lists `source_url`/`source_file_name` in
  `source_data_fields`.
- The runner links every response to the conversation (`conversation=conversation.id`)
  and does **not** pass `previous_response_id` (the two are mutually exclusive).
