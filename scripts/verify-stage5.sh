#!/usr/bin/env bash
# verify-stage5.sh — router-on-a-stick funcional + ICMP inter-VLAN
set -Eeuo pipefail

echo "== gateways en fw1 =="
docker exec lab-fw1 ip -4 addr show | grep "10.10\." || { echo "no hay subinterfaces"; exit 1; }

echo
echo "== A) canal pc10a -> gateway 10.10.10.1 =="
docker exec lab-pc10a ping -c2 -W2 10.10.10.1 && echo "A: PASS" || echo "A: FAIL"

echo
echo "== B) canal pc10a -> pc99 10.10.99.20 (inter-VLAN ruteado) =="
docker exec lab-pc10a ping -c2 -W2 10.10.99.20 && echo "B: PASS" || echo "B: FAIL"

echo
echo "== C) políticas nftables base en fw1 =="
docker exec lab-fw1 nft -s list ruleset | head -12
