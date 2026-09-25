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
sudo mkdir -p /var/run/openvswitch
echo "setup done"
