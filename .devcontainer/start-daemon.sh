#!/usr/bin/env bash
# =================================================================
# .devcontainer/start-daemon.sh — arranque de subsistemas del lab
# Se ejecuta con postStartCommand (usuario vscode, sudo passwordless).
# =================================================================
set -e

echo "=== Starting Background Daemons ==="

# 0) Docker daemon (requiere contenedor privilegiado)
if ! sudo docker info >/dev/null 2>&1; then
  sudo dockerd --iptables=false --bridge=none >/tmp/dockerd.log 2>&1 &
fi

# 1) Open vSwitch (kernel datapath; requiere privilegios)
sudo mkdir -p /var/run/openvswitch
if [ ! -S /var/run/openvswitch/db.sock ]; then
  sudo ovsdb-server /etc/openvswitch/conf.db \
    --remote=punix:/var/run/openvswitch/db.sock \
    --remote=db:Open_vSwitch,Open_vSwitch,manager_options \
    --pidfile --detach >/tmp/ovsdb.log 2>&1 || true
  sudo ovs-vsctl --no-wait init
  sudo ovs-vswitchd --pidfile --detach >/tmp/ovs-vswitchd.log 2>&1 || true
fi

# 2) GNS3 Server daemon
mkdir -p /home/vscode/GNS3/{images,projects,appliances} /home/vscode/.config/GNS3/2.2
cp -f "$(pwd)/.devcontainer/gns3_server.conf" /home/vscode/.config/GNS3/2.2/gns3_server.conf

echo "[*] Launching GNS3 Server daemon on 0.0.0.0:3080..."
if pgrep -f "gns3server" >/dev/null; then
  pkill -f "gns3server" || true
  sleep 1
fi
nohup gns3server --config /home/vscode/.config/GNS3/2.2/gns3_server.conf > /tmp/gns3server.log 2>&1 &
sleep 3
echo "[+] GNS3 Server pid: $(pgrep -f gns3server | head -n1 || echo none)"

# 3) OpenSSH (2222) para acceso alterno — se instala en setup.sh
if ! pgrep -f "sshd" >/dev/null; then
  sudo mkdir -p /run/sshd
  sudo /usr/sbin/sshd -p 2222 >/tmp/sshd.log 2>&1 || true
fi

echo "=== Daemons Ready ==="
exit 0
