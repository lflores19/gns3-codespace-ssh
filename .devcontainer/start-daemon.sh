#!/usr/bin/env bash
# Arranque postStart: dockerd (dind) + openvswitch + gns3
set -e

echo "=== Starting Background Daemons ==="

if command -v docker >/dev/null 2>&1 && ! docker info >/dev/null 2>&1; then
  sudo rm -f /var/run/docker.pid /var/run/docker/containerd/containerd.pid 2>/dev/null || true
  (sudo dockerd >/tmp/dockerd.log 2>&1 &)
  for i in $(seq 1 30); do
    if sudo docker info >/dev/null 2>&1; then break; fi
    sleep 1
  done
fi

sudo mkdir -p /var/run/openvswitch 2>/dev/null || true
if command -v ovsdb-server >/dev/null 2>&1; then
  if ! sudo test -S /var/run/openvswitch/db.sock; then
    sudo ovsdb-server /etc/openvswitch/conf.db \
      --remote=punix:/var/run/openvswitch/db.sock \
      --pidfile --detach >/tmp/ovsdb.log 2>&1 || true
    sudo ovs-vsctl --no-wait init 2>/dev/null || true
  fi
  pgrep ovs-vswitchd >/dev/null 2>&1 || sudo ovs-vswitchd --pidfile --detach >/tmp/ovs-vswitchd.log 2>&1 || true
fi

mkdir -p /home/vscode/GNS3/{images,projects,appliances} /home/vscode/.config/GNS3/2.2
cp -f "$(pwd)/.devcontainer/gns3_server.conf" /home/vscode/.config/GNS3/2.2/gns3_server.conf 2>/dev/null || true
if ! pgrep -f gns3server >/dev/null 2>&1; then
  nohup gns3server --config /home/vscode/.config/GNS3/2.2/gns3_server.conf >/tmp/gns3server.log 2>&1 &
fi

echo "=== Daemons Ready ==="
