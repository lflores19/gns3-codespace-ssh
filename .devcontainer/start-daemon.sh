#!/usr/bin/env bash
set -e

echo "=== Starting Background Daemons ==="

# 1. Start SSH Daemon
if ! pgrep -x "sshd" > /dev/null; then
    echo "[*] Starting SSH daemon on port 2222..."
    sudo /usr/sbin/sshd -D -p 2222 &
    echo "[+] SSH daemon active."
fi

# 2. Start GNS3 Server Daemon
if ! pgrep -f "gns3server" > /dev/null; then
    echo "[*] Launching GNS3 Server daemon on 0.0.0.0:3080..."
    nohup gns3server --config /home/vscode/.config/GNS3/2.2/gns3_server.conf > /tmp/gns3server.log 2>&1 &
    sleep 2
    if pgrep -f "gns3server" > /dev/null; then
        echo "[+] GNS3 Server running (PID: $(pgrep -f gns3server | head -n 1))."
    else
        echo "[!] Warning: Check /tmp/gns3server.log for details."
    fi
else
    echo "[i] GNS3 Server already running."
fi

echo "=== Daemons Ready ==="
