#!/usr/bin/env bash
# verify-stage5.sh — gateways router-on-a-stick (matriz restrictiva ya instalada)
set -Eeuo pipefail

P(){ echo "PASS $1"; }
F(){ echo "FAIL $1"; exit 1; }

echo "== gateways en fw1 =="
for ip in 10.10.10.1 10.10.20.1 10.10.30.1 10.10.40.1 10.10.50.1; do
  docker exec lab-fw1 ip -4 addr show | grep -q "$ip/" && P "gw $ip" || F "gw $ip"
done

echo
echo "== pc10a -> 10.10.10.1 (mismo VLAN, ICMP) =="
docker exec lab-pc10a ping -c2 -W2 10.10.10.1 >/dev/null && P pc10a-gw || F pc10a-gw

echo "== pc50 -> 10.10.50.1 (mismo VLAN, ICMP) =="
docker exec lab-pc50 ping -c2 -W2 10.10.50.1 >/dev/null && P pc50-gw || F pc50-gw

echo
echo "== note SEC01: ping inter-VLAN debe FALLAR (todo L3 a otro VLAN requiere servicio explícito) =="
if docker exec lab-pc10a ping -c2 -W2 10.10.50.101 >/dev/null 2>&1; then
  echo "B: FAIL — inter-VLAN abierto, la matriz no está aplicándose"; exit 1
else
  P intervlan-bloqueado
fi
