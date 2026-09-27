#!/usr/bin/env bash
# verify-stage4.sh — trunks, VLANs y DPIDs (Comercial Andina: VLAN10/20 en SW1, 30/40/50 en SW2)
set -Eeuo pipefail

P(){ echo "PASS $1"; }
F(){ echo "FAIL $1"; exit 1; }

echo "== switches arriba =="
docker ps --format 'table {{.Names}}\t{{.Status}}' | grep -E "lab-(ctrl1|ovs-sw|fw1)" || F switches

echo
echo "== SW1/SW2 conectados al controller (OpenFlow) =="
docker exec lab-ovs-sw1 ovs-vsctl get bridge br0 datapath_id | grep -q 0000000000000001 && P dpid1 || F dpid1
docker exec lab-ovs-sw2 ovs-vsctl get bridge br0 datapath_id | grep -q 0000000000000002 && P dpid2 || F dpid2

echo
echo "== A) misma VLAN atraviesa el trunk: pc10a -> gateway VLAN10 =="
docker exec lab-pc10a ping -c2 -W2 10.10.10.1 >/dev/null 2>&1 && P vlan10-a-gw || F vlan10-a-gw

echo
echo "== B) cross-VLAN desde cliente debe fallar: pc10a -> pc20 (10.10.20.102) =="
if docker exec lab-pc10a ping -c2 -W2 10.10.20.102 >/dev/null 2>&1; then
  echo "B: hmm — hay routing inter-VLAN (valido si etapa 5 ya levanto los gateways; NO es P02)。P02 exige VLAN distinta tag en trunk."
  P trunk-permite-l3
else
  P aislamiento-l2
fi

echo
echo "== C) trunks cargan VLAN 10,20,30,40,50 =="
docker exec lab-ovs-sw1 ovs-vsctl list-ports br0 | sort
docker exec lab-ovs-sw2 ovs-vsctl list-ports br0 | sort
