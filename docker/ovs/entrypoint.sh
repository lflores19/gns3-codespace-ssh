#!/usr/bin/env bash
# entrypoint OVS switch for lab (etapa 4: VLANs + trunk)
# spec: OpenFlow 1.3, controller over OOB, fail-mode secure
#
# Configuración de puertos vía OVS_PORTS, por ejemplo:
#   OVS_PORTS="eth1=trunk:10,20,30,40,99 eth2=access:10 eth3=access:99"
set -Eeuo pipefail

BRIDGE="${OVS_BRIDGE:-br0}"
CTRL_IP="${OVS_CTRL_IP:-172.29.250.10}"
CTRL_PORT="${OVS_CTRL_PORT:-6653}"
PORTS="${OVS_PORTS:-}"

# sockets/db
mkdir -p /var/run/openvswitch
rm -f /var/run/openvswitch/db.sock
/usr/share/openvswitch/local/bin/ovsdb-server \
  --remote=punix:/var/run/openvswitch/db.sock \
  --remote=db:Open_vSwitch,Open_vSwitch,manager_options \
  --pidfile --detach

ovs-vswitchd unix:/var/run/openvswitch/db.sock --pidfile --detach=monitor

# bridge + fail-mode "secure" (spec §4): no aprendizaje si sin controller
ovs-vsctl --timeout=10 --may-exist add-br "$BRIDGE"
ovs-vsctl set bridge "$BRIDGE" protocols=OpenFlow13
ovs-vsctl set-fail-mode "$BRIDGE" secure
ovs-vsctl set-controller "$BRIDGE" "tcp:${CTRL_IP}:${CTRL_PORT}"

# puertos declarados en OVS_PORTS
for p in $PORTS; do
  name="${p%%=*}"; spec="${p#*=}"
  # esperar a que docker adjunte la interfaz
  for i in 1 2 3 4 5 6 7 8 9 10; do
    [ -e "/sys/class/net/$name" ] && break
    sleep 1
  done
  mode="${spec%%:*}"; vlans="${spec#*:}"
  if [ "$mode" = "trunk" ]; then
    ovs-vsctl --may-exist add-port "$BRIDGE" "$name" tag="" trunks="$vlans"
    echo "[*] $name trunk vlans=$vlans"
  elif [ "$mode" = "access" ]; then
    ovs-vsctl --may-exist add-port "$BRIDGE" "$name" tag="$vlans"
    echo "[*] $name access vlan=$vlans"
  else
    echo "[!] $name modo desconocido: $mode" >&2
    exit 1
  fi
  ip link set dev "$name" up
done

echo "[*] OVS listo: bridge=$BRIDGE controller=tcp:${CTRL_IP}:${CTRL_PORT} fail=secure"
ovs-vsctl show

trap 'ovs-vsctl --if-exists del-br "$BRIDGE" || true' TERM INT
tail -F /var/log/openvswitch/ovs-vswitchd.log /dev/null &
wait $!
