#!/usr/bin/env bash
# verify-stage6.sh — matriz SEC01 con reglas counter-backed.
# Cada check espera un resultado concreto: PASS solo si coincide el criterio.
set -Eeuo pipefail

P(){ echo "PASS $1"; }
F(){ echo "FAIL $1"; exit 1; }

echo "== A) FW01: Adm->servidores == (esperado: ALLOW)"
docker exec lab-pc10a ping -c2 -W2 10.10.30.20 >/dev/null 2>&1 && P adm-srv || F adm-srv

echo "== B) FW02: Ventas->443 (esperado: ALLOW cuando exista web; si no hay servicio, pasan paquetes pero no handshake) =="
docker exec lab-fw1 nft list chain ip filter forward | grep -q "ventas-srv-443-445" && P ventas-443-regla || F ventas-443-regla

echo "== C) FW04: Invitados->LAN bloqueado =="
docker exec lab-pc10a ping -c1 -W2 10.10.40.101 >/dev/null 2>&1 && true
# test real requiere pc-inv40 exista en compose; pendiente al arranque del host.
echo "C: pendiente (requiere cliente VLAN40)"

echo "== D) FW06: counters activos =="
docker exec lab-fw1 nft -s list chain ip filter forward | grep -E "counter packets [0-9]+" >/dev/null && P counters || F counters

echo "Nota: la regla final 'counter drop' es el denegar por default."
