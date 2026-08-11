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
pip install azure-ai-projects==2.3.0
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



