#!/usr/bin/env bash
# verify-stage5.sh — gateways router-on-a-stick y NAT base
set -Eeuo pipefail

P(){ echo "PASS $1"; }
F(){ echo "FAIL $1"; exit 1; }

echo "== gateways en fw1 =="
for ip in 10.10.10.1 10.10.20.1 10.10.30.1 10.10.40.1 10.10.50.1; do
  docker exec lab-fw1 ip -4 addr show | grep -q "$ip/" && P "gw $ip" || F "gw $ip"
done

echo
echo "== pc10a -> 10.10.10.1 =="
docker exec lab-pc10a ping -c2 -W2 10.10.10.1 >/dev/null && P pc10a-gw || F pc10a-gw

echo "== pc50 -> 10.10.50.1 =="
docker exec lab-pc50 ping -c2 -W2 10.10.50.1 >/dev/null && P pc50-gw || F pc50-gw

echo
echo "== etapa 5: inter-VLAN permitido (antes del SEC01) =="
docker exec lab-pc10a ping -c2 -W2 10.10.50.101 >/dev/null && P intervlan-ok || F intervlan-ok
