#!/usr/bin/env bash
# Firewall router-on-a-stick para el lab local (etapa 5).
# Crea subinterfaces dot1Q, gateway por VLAN, activa forwarding y carga nftables.
#
# Entorno:
#   FW_UPLINK   interfaz trunk (eth1 adjuntada a "backbone")
#   FW_VS       lista "vid:ip/mask" de gateways
#   NFT_FILE    plantilla nftables
set -Eeuo pipefail

UPLINK="${FW_UPLINK:-eth1}"
VLAN_GWS="${FW_VLANS:-10:10.10.10.1/24 20:10.10.20.1/24 99:10.10.99.1/24}"
NFT_FILE="${NFT_FILE:-/etc/firewall/fw.nft}"

[ -e "/sys/class/net/$UPLINK" ] || { echo "no existe $UPLINK"; exit 1; }

sysctl -w net.ipv4.ip_forward=1 >/dev/null

for item in $VLAN_GWS; do
  vid="${item%%:*}"; addr="${item#*:}"
  sub="${UPLINK}.${vid}"
  ip link add link "$UPLINK" name "$sub" type vlan id "$vid" 2>/dev/null || true
  ip addr replace "$addr" dev "$sub"
  ip link set "$sub" up
  echo "[*] gateway $addr en $sub"
done

# nftables
[ -f "$NFT_FILE" ] && nft -f "$NFT_FILE" && echo "[*] nftables cargado ($NFT_FILE)"
nft -s list ruleset | head -30

echo "[*] firewall listo"
exec sleep infinity
