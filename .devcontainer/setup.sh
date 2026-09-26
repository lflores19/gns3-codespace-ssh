#!/usr/bin/env bash
# postCreateCommand: instalar stack de red/emulación (una sola vez)
set -e
export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get install -y --no-install-recommends \
    openvswitch-switch tcpdump dnsutils jq python3-pip postgresql-client \
    iproute2 iputils-ping
pip3 install --no-cache-dir ryu gns3fy pyyaml "gns3-server==2.2.55"

sudo apt-get install -y --no-install-recommends dynamips vpcs ubridge qemu-system-x86 telnet || true

# Codespaces removes CAP_NET_ADMIN from the bounding set. Copy without file
# capabilities so uBridge can use its supported unprivileged UDP transport.
install -Dm755 /usr/bin/ubridge /home/vscode/.local/bin/ubridge-uncap
install -Dm755 /usr/bin/dynamips /home/vscode/.local/bin/dynamips-uncap

echo "setup done"
