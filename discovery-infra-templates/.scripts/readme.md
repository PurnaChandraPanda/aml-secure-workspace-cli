
## cleanup script for Discovery RG
```
# Required for Git Bash on Windows so /subscriptions/... is not path-converted.
export MSYS_NO_PATHCONV=1


az login
./cleanup_discovery.sh rg-uks4discovery 6977e295-0d7c-4557-8e0b-26e2f6532103
```

## cleanup sequence for Discovery resources based RG
 1. Discovery Agents
 2. Discovery Project
 3. Discovery ChatDeploymentModel
 4. Discovery Workspace
 5. Discovery Tools
 6. Discovery nodepool
 7. Discovery supercomputer
 8. Discovery bookshelf
 9. Discovery Storage Asset
10. Discovery Storage Container

