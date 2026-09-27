#!/usr/bin/env bash
# entrypoint OVS switch — descubre interfaces POR SUBNET (no asume eth names).
# OVS_PORTS="SUBNET=trunk:vids SUBNET=access:vid ..."
set -Eeuo pipefail

BRIDGE="${OVS_BRIDGE:-br0}"
CTRL_IP="${OVS_CTRL_IP:-10.10.99.10}"
CTRL_PORT="${OVS_CTRL_PORT:-6653}"
DPID="${OVS_DPID:-0000000000000001}"
PORTS="${OVS_PORTS:-}"

mkdir -p /var/run/openvswitch
rm -f /var/run/openvswitch/db.sock
/usr/share/openvswitch/local/bin/ovsdb-server \
  --remote=punix:/var/run/openvswitch/db.sock \
  --remote=db:Open_vSwitch,Open_vSwitch,manager_options \
  --pidfile --detach
ovs-vswitchd unix:/var/run/openvswitch/db.sock --pidfile --detach=monitor

ovs-vsctl --timeout=10 --may-exist add-br "$BRIDGE"
ovs-vsctl set bridge "$BRIDGE" protocols=OpenFlow13
ovs-vsctl set bridge "$BRIDGE" other-config:datapath-id="$DPID"
ovs-vsctl set-fail-mode "$BRIDGE" secure
ovs-vsctl set-controller "$BRIDGE" "tcp:${CTRL_IP}:${CTRL_PORT}"

find_if_by_net() {  # $1=CIDR
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

for spec in $PORTS; do
  net="${spec%%=*}"; rest="${spec#*=}"
  mode="${rest%%:*}"; vlans="${rest#*:}"
  ifname=""
  for i in 1 2 3 4 5 6 7 8 9 10; do
    ifname="$(find_if_by_net "$net")"
    [ -n "$ifname" ] && break
    sleep 1
  done
  [ -n "$ifname" ] || { echo "no encontre IF para $net"; exit 1; }
  ip addr flush dev "$ifname" 2>/dev/null || true
  ip link set dev "$ifname" up
  if [ "$mode" = "trunk" ]; then
    ovs-vsctl --may-exist add-port "$BRIDGE" "$ifname" trunks="$vlans"
    echo "[*] $ifname trunk vlans=$vlans"
  else
    ovs-vsctl --may-exist add-port "$BRIDGE" "$ifname" tag="$vlans"
    echo "[*] $ifname access vlan=$vlans"
  fi
done

echo "[*] OVS listo bridge=$BRIDGE dpid=$DPID ctrl=tcp:${CTRL_IP}:${CTRL_PORT} fail=secure"
ovs-vsctl show
trap 'ovs-vsctl --if-exists del-br "$BRIDGE" || true' TERM INT
tail -F /var/log/openvswitch/ovs-vswitchd.log /dev/null &
wait $!
