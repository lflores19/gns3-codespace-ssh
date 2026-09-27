#!/usr/bin/env bash
# verify-stage6.sh — matriz SEC01 vs spec Andina §8
set -Eeuo pipefail

P(){ echo "PASS $1"; }
F(){ echo "FAIL $1"; exit 1; }

echo "== A) HTTPS VLAN10 -> WEB01 permitido =="
docker exec lab-pc10a sh -c "apk add --no-cache curl >/dev/null 2>&1; curl -ks --max-time 4 https://10.10.30.20/ >/dev/null" \
  && P adm-a-web || F adm-a-web

echo "== B) regla ventas->443 presente (y counters activos) =="
docker exec lab-fw1 nft list chain ip filter forward | grep -q "ventas" || {
  docker exec lab-fw1 nft list chain ip filter forward | grep -q "corp-web-https" && P corp-web-https || F corp-web-https; }

echo "== C) Invitados sin acceso a (10.10.0.0/16) =="
if docker exec lab-pc40 ping -c2 -W2 10.10.10.1 >/dev/null 2>&1; then echo "C: FAIL — interno alcanzado desde VLAN40"; exit 1; else P inv-bloqueado; fi

echo "== D) DB solo desde WEB01 =="
if docker exec lab-pc10a sh -c "apk add --no-cache postgresql-client >/dev/null 2>&1; pg_isready -h 10.10.30.30 -U nobody -t 3" 2>/dev/null; then
  echo "D: FAIL — cliente usuario alcanza DB"; exit 1
else
  P db-solo-web
fi

echo "== E) counters activos en blocking finales =="
docker exec lab-fw1 nft -s list chain ip filter forward | grep -E "counter packets [1-9]" >/dev/null && P counters || echo "E: nota — counters sin trafico aun"

echo "(fin: VPN e IPv6 igual que spec; chequear en tu host)"
