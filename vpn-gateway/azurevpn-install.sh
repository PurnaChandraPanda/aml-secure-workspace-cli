#!/bin/bash

set -e

PKG="microsoft-azurevpnclient"

# Add the condition to check if azure vpn client is installed; install it otherwise

if ! dpkg -s "$PKG" >/dev/null 2>&1; then
    echo "$PKG is not installed"

    # Install Microsoft's public key
    curl -sSl https://packages.microsoft.com/keys/microsoft.asc | sudo tee /etc/apt/trusted.gpg.d/microsoft.asc

    # Install the production repo list for jammy
    # For Ubuntu 22.04
    curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list | sudo tee /etc/apt/sources.list.d/microsoft-ubuntu-jammy-prod.list

    sudo apt-get update -y

    sudo apt-get install $PKG -y
else
    echo "$PKG is already installed"
fi

# 1. is the pkg really present?
dpkg -s microsoft-azurevpnclient | grep -E 'Status|Version' || echo "package missing"

# 2. find where the binary actually lives
BIN_CANDIDATES=(
  /opt/microsoft/azurevpnclient/bin/azvpn                              # ≥ 2.0
  /opt/microsoft/microsoft-azurevpnclient/microsoft-azurevpnclient     # 3.0
)

FOUND_BIN=""
for cand in "${BIN_CANDIDATES[@]}"; do
  if [[ -x "$cand" ]]; then
    FOUND_BIN="$cand"
    break
  fi
done

if [[ -z "$FOUND_BIN" ]]; then
  echo "Azure VPN binary not found - install step may have failed."
  exit 1
fi

# 3. create /usr/local/bin/azurevpn symlink if missing
if ! command -v azurevpn >/dev/null 2>&1; then
  sudo ln -sf "$FOUND_BIN" /usr/local/bin/azurevpn
  echo "Created symlink /usr/local/bin/azurevpn -> $FOUND_BIN"
fi

echo "over"

