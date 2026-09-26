#!/usr/bin/env bash
# verify-stage8.sh — SDN01-03 pruebas del prompt
set -Eeuo pipefail

echo "== SDN01: el controller programa flows OF13 =="
docker exec lab-ovs-sw1 ovs-ofctl -O OpenFlow13 dump-flows br0

echo "== SDN02: bloqueo/restauración política (ventas->HTTPS intranet) =="
echo "criterio esperado: controller instala drop-rule con cookie documentado; ping 10.10.20.x->10.10.30.20:443 falla; luego se restaura"

echo "== SDN03: pérdida del controlador =="
echo "criterio esperado: fail-mode secure mantiene flows instalados; tráfico existente sigue hasta timeout; NO prometer corte instantáneo"

# ejecución automatizable (se añade una vez medido en host):
# docker compose -f deploy/host/docker-compose.sdn.yml stop controller
# docker exec lab-pc10a ping ... # qué sigue y qué no
# docker compose ... start controller
