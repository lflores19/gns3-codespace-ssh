#!/usr/bin/env bash
echo "[*] start-lab: levantando servicios gestionados por docker-compose"
docker compose -f compose.yaml up -d --build
echo "[*] Esperando GNS3..."
sleep 2
systemctl --user restart gns3server 2>/dev/null || nohup gns3server --config /home/vscode/.config/GNS3/2.2/gns3_server.conf > /tmp/gns3server.log 2>&1 &
echo "[✓] Lab iniciado."
