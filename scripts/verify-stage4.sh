#!/usr/bin/env bash
# verify-stage4.sh — checks NET03/NET04 mínimos de etapa 4 (VLANs+trunk)
set -Eeuo pipefail
cd "$(dirname "$0")/../deploy/host"

echo "== switches arriba =="
docker compose -f docker-compose.sdn.yml ps --format 'table {{.Name}}\t{{.Status}}' | tail -n +2

echo
echo "== A) mismo VLAN a través del trunk (debe pasar) pc10a -> pc10b =="
docker exec lab-pc10a ping -c2 -W2 10.10.10.102 && echo "A: PASS" || echo "A: FAIL"

echo
echo "== B) cross-VLAN desde cliente (debe fallar) pc10a -> pc99 (10.10.99.20) =="
if docker exec lab-pc10a ping -c2 -W2 10.10.99.21 >/dev/null 2>&1; then
  echo "B: FAIL (hubo L2 cross-VLAN)"; exit 1
else
  echo "B: PASS (aislada; necesitaría routing para llegar a 99)"
fi

echo
echo "== C) flows presentes en SW1 (OF13) =="
docker exec lab-ovs-sw1 ovs-ofctl -O OpenFlow13 dump-flows br0 | head -5
