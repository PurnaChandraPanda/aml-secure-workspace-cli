## For v1 (in venv)
```
pip install azure-ai-projects==1.1.0b4
```

```powershell
cd foundry-agent/v1-agents

python list-deployments.py

# create/ run agent
python create-agent.py
python run-agent.py

# create ai search agent/ run
python create-aisearch-agent.py
python run-agent.py
```

## For v2 (in venv)
```
pip install azure-ai-projects==2.3.0 (or later)
```

```powershell
cd foundry-agent/v2-agents

# create/ run agent
python v2create-agent.py
python v2run-agent.py

# run agent via rapi
python v2run-rapi.py

# create ai search agent/ run
python create-aisearch-agent.py
python v2run-agent.py

# run agent in stream mode
python run-agent-stream.py

# create file search agent/ run
python create-filesearch-agent.py
python v2run-agent.py
```

### For search citation
As in these py files there's no `.env` mapped, before running the codes be sure to update foundry project, search connection, index details properly.

As a pre-requisite of this sample, run [1.1.citation_build_rag_pipeline.py](azure-search-rag/1.1.citation_build_rag_pipeline.py). This will get search index created to ensure citation part is properly reflected with `source_url` details.

```bash
cd foundry-agent/v2-agents # (if not already done)

# register index asset in foundry
python register-search-index-asset.py

# create prompt agent that has custom field mapping for index retrieve as tool (refer to existing index asset)
python create-aisearch-agent-with-url.py 

# run prompt agent to show url citation
python run-agent-stream.py
```

## For Foundry IQ KB citation in Foundry prompt agents

- To work with search service, from client side, make sure `azure-search-documents==12.0.0` (or latest) is installed.
- Use existing AI Search index with a mix of semantic configuration to create knowledge base.

```bash
cd foundry-agent/v2-agents # (if not already done)

# Set foundry/ model param details inside the file
# 1. create semantic config + KS + KB
python kb_build_knowledge_base.py

# Set foundry/ model param details inside the file
# 2. prints the agent version...
python create-kb-function-agent.py

# Set foundry/ model param details inside the file
# set AGENT_VERSION in run-kb-agent-stream.py to that number, then:
# 3. run the KB-backed agent
python run-kb-agent-stream.py
```

