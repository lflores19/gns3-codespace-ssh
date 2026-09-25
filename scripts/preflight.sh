#!/usr/bin/env bash
# =================================================================
# scripts/preflight.sh  —  FASE 1: Diagnóstico del entorno
# Ejecutar DENTRO del codespace. Genera docs/preflight.md.
# =================================================================
set -uo pipefail

OUT=${1:-docs/preflight.md}
mkdir -p "$(dirname "$OUT")" evidence

{
echo "# Preflight / Diagnóstico del entorno"
echo
echo "- Fecha UTC: $(date -u +%F' '%T' Z')"
echo "- Hostname: $(hostname)"
echo "- Usuario: $(whoami)"
echo
echo "## 1. Captación de Infraestructura Base"
echo '```'
uname -a
cat /etc/os-release | head -n 5 || true
echo '```'
echo
echo "## 2. Hardware y Capacidad"
echo '```'
nproc
free -h
df -h /codespace 2>/dev/null || df -h /workspaces 2>/dev/null || df -h /
echo '```'
echo
echo "## 3. Herramientas base instaladas"
echo '```'
for c in git curl wget jq python3 pip3 docker docker-compose openvpn samba openvswitch-vswitchd ovs-vsctl ovs-ofctl ryu-manager; do
  if command -v "$c" >/dev/null 2>&1; then
    echo "[OK]  $c -> $(command -v "$c")"
  else
    echo "[MISS] $c"
  fi
done
echo '```'
echo
echo "## 4. Docker daemon / estado"
echo '```'
docker info --format '{{json .ServerVersion}} {{json .Driver}} {{json .OperatingSystem}}' 2>/dev/null || echo "Docker no disponible o no configurado"
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}' 2>/dev/null || true
echo '```'
echo
echo "## 5. GNS3 Server"
echo '```'
gns3server --version 2>/dev/null || echo "GNS3 no instalado aún"
ps aux | grep gns3 | grep -v grep || echo "GNS3 no está corriendo"
if [ -f /home/vscode/.config/GNS3/2.2/gns3_server.conf ]; then
  echo "---gns3_server.conf---"
  cat /home/vscode/.config/GNS3/2.2/gns3_server.conf
fi
echo '```'
echo
echo "## 6. Red y Puertos Activos"
echo '```'
ip addr show | grep -E '(inet |^[0-9]+:)' | grep -v '127.0.0.1' | head -n 20 || true
ss -tlnp 2>/dev/null | grep -E '(3080|5000|5001|5900|5901|2222|53|80|443|5000)' || echo "Sin listeners esperados en puertos críticos"
echo '```'
echo
echo "## 7. Generando evidencia cruda"
date -u +%FT%TZ > evidence/preflight.run.txt
docker info 2>/dev/null | head -n 30 >> evidence/preflight.run.txt || echo "docker info falló" >> evidence/preflight.run.txt
gns3server --version 2>/dev/null > evidence/GNS3.version.txt || echo "not installed" > evidence/GNS3.version.txt
echo
echo "## 8. Conclusión"
echo "> Diagnóstico automatizado completado. Ver docs/estado.md para estado global."
} | tee "$OUT"

# Requisito estado actual (PENDING para fases futuras)
sed -i 's/PENDING$/NOT_EVALUATED/' docs/matriz-requisitos.csv 2>/dev/null || true

echo "[✓] Preflight completado. Ver $OUT"
