
## For Windows `git bash`
- Open windows terminal or powershell
- Run the install command
- Close all open terminals
- Note: Open new terminal or vscode session to get `jq` working

```
winget install -e --id jqlang.jq
```

## For Ubuntu
```
sudo apt update
sudo apt install jq
```

---

## Update project caphost

### Option 1: update project caphost

Since updates aren't supported for capability hosts, follow this sequence for configuration changes.

- Delete the existing capability host at project level

```
cd scripts-caphost {if not already}
./0.get_caphost.sh
```

- Wait for deletion to complete

```
cd scripts-caphost {if not already}
./1.delete_caphost.sh
```

- Create a new capability host at project level with the desired configuration

```
cd scripts-caphost {if not already}
./2.recreate_caphost.sh
```

- **Remember** to set the actual values of respective foundry resource. Then, run the .sh files in git bash or ubuntu terminal.

### Option 2: update project caphost

```
cd scripts-caphost {if not already}
./recreate.sh
```

