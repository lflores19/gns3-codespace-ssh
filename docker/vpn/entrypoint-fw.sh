#!/usr/bin/env bash
# Firewall router-on-a-stick — descubre interfaces POR SUBNET.
# FW_TRUNK_NET: red trunk donde cuelgan las subinterfaces VLAN
# FW_WAN_NET:  red WAN
# FW_VLANS:    "vid:ip/mask ..."
set -Eeuo pipefail

TRUNK_NET="${FW_TRUNK_NET:-10.255.0.0/30}"
WAN_NET="${FW_WAN_NET:-192.0.2.0/24}"
VLAN_GWS="${FW_VLANS:-}"
NFT_FILE="${NFT_FILE:-/etc/firewall/fw.nft}"

find_if_by_net() {
  local target_net="$1"
  python3 -c "
import sys, ipaddress, subprocess
target = ipaddress.ip_network('$target_net', strict=False)
out = subprocess.check_output(['ip', '-o', '-4', 'addr', 'show'], text=True)
for line in out.splitlines():
    parts = line.split()
    if len(parts) >= 4:
        ifname = parts[1]
        addr = parts[3]
        if ipaddress.ip_interface(addr).ip in target:
            print(ifname)
            sys.exit(0)
sys.exit(1)
" 2>/dev/null || true
}

UPLINK=""; WANIF=""
for i in $(seq 1 10); do
  [ -z "$UPLINK" ] && UPLINK="$(find_if_by_net "$TRUNK_NET")"
  [ -z "$WANIF" ]  && WANIF="$(find_if_by_net "$WAN_NET")"
  [ -n "$UPLINK" ] && [ -n "$WANIF" ] && break
  sleep 1
done
[ -n "$UPLINK" ] || { echo "sin trunk ($TRUNK_NET)"; exit 1; }
[ -n "$WANIF" ]  || { echo "sin wan ($WAN_NET)"; exit 1; }

# nombrado estable para que fw.nft use nombres conocidos
ip link set dev "$UPLINK" name trunk0 2>/dev/null || true
ip link set dev "$WANIF" name wan0   2>/dev/null || true

sysctl -w net.ipv4.ip_forward=1 >/dev/null

for item in $VLAN_GWS; do
  vid="${item%%:*}"; addr="${item#*:}"
  sub="trunk0.${vid}"
  ip link add link trunk0 name "$sub" type vlan id "$vid" 2>/dev/null || true
  ip addr replace "$addr" dev "$sub"
  ip link set "$sub" up
  echo "[*] gateway $addr en $sub"
done

# DHCP relay: VLAN10/20/40/50 -> 10.10.30.10 (Kea en INFRA01)
if command -v dhcrelay >/dev/null 2>&1; then
  dhcrelay -4 -i trunk0.10 -i trunk0.20 -i trunk0.40 -i trunk0.50 10.10.30.10 &
  echo "[*] dhcrelay activo"
else
  echo "[!] dhcrelay no disponible: P01 DHCP no pasara; instala paquete dhcp en el Dockerfile"
fi

[ -f "$NFT_FILE" ] && nft -f "$NFT_FILE" && echo "[*] nftables cargado ($NFT_FILE)"
nft -s list ruleset | head -30
echo "[*] firewall listo"
exec sleep infinity
