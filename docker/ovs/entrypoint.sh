#!/usr/bin/env bash
# entrypoint OVS switch for lab
# spec: OpenFlow 1.3, controller over OOB, fail-mode secure
set -Eeuo pipefail

BRIDGE="${OVS_BRIDGE:-br0}"
CTRL_IP="${OVS_CTRL_IP:-172.29.250.10}"
CTRL_PORT="${OVS_CTRL_PORT:-6653}"
OVS_SOCK="unix:/var/run/openvswitch/db.sock"

# sockets/db
mkdir -p /var/run/openvswitch
rm -f /var/run/openvswitch/db.sock
/usr/share/openvswitch/local/bin/ovsdb-server \
  --remote=punix:/var/run/openvswitch/db.sock \
  --remote=db:Open_vSwitch,Open_vSwitch,manager_options \
  --pidfile --detach

ovs-vsctl --db="$OVS_SOCK" --no-wait init
ovs-vswitchd unix:/var/run/openvswitch/db.sock --pidfile --detach=monitor

# bridge + fail-mode "secure" (spec §4 policía): no aprendizaje si sin controller
ovs-vsctl --timeout=10 --may-exist add-br "$BRIDGE"
ovs-vsctl set bridge "$BRIDGE" protocols=OpenFlow13
ovs-vsctl set-fail-mode "$BRIDGE" secure
ovs-vsctl set-controller "$BRIDGE" "tcp:${CTRL_IP}:${CTRL_PORT}"

echo "[*] OVS listo: bridge=$BRIDGE controller=tcp:${CTRL_IP}:${CTRL_PORT} fail=secure"
ovs-vsctl show

# keep container alive + trap cleanup
trap 'ovs-vsctl --if-exists del-br "$BRIDGE" || true' TERM INT
tail -f /var/log/openvswitch/ovs-vswitchd.log /dev/null &
wait $!
