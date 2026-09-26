#!/usr/bin/env bash
# preflight-host.sh — chequeo GO/NO-GO para el host local destino (WSL2 Ubuntu).
# Corre dónde se vaya a desplegar el lab. No modifica nada: solo informa.
set -uo pipefail

PASS=0; FAIL=0; WARN=0
ok()   { PASS=$((PASS+1)); echo "[OK]   $*"; }
fail() { FAIL=$((FAIL+1)); echo "[FAIL] $*"; }
warn() { WARN=$((WARN+1)); echo "[WARN] $*"; }

echo "=== Preflight host (WSL2/Ubuntu local) ==="
echo "fecha: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "host:  $(hostname)  kernel: $(uname -r)"

# 1) capabilities
BND="$(awk '/CapBnd/ {print $2}' /proc/self/status)"
SYSADMIN=$(( (0x$BND >> 21) & 1 )); NETADMIN=$(( (0x$BND >> 12) & 1 ))
[ "$SYSADMIN" = 1 ] && ok "SYS_ADMIN presente" || fail "SYS_ADMIN ausente (CapBnd=$BND)"
[ "$NETADMIN" = 1 ] && ok "NET_ADMIN presente" || fail "NET_ADMIN ausente (CapBnd=$BND)"

# 2) devices
[ -e /dev/kvm ]      && ok "/dev/kvm"      || warn "/dev/kvm ausente (QEMU TCG también funciona, solo más lento)"
[ -e /dev/net/tun ]  && ok "/dev/net/tun"  || fail "/dev/net/tun ausente (OpenVPN / OVS userspace no viable)"

# 3) Docker
if command -v docker >/dev/null 2>&1; then
  ok "docker CLI: $(docker --version)"
  if docker info >/dev/null 2>&1; then
    ok "docker daemon accesible"
    DRV="$(docker info --format '{{.Driver}}' 2>/dev/null)"
    [ "$DRV" = "overlay2" ] && ok "storage-driver: overlay2" || warn "storage-driver: $DRV (esperado overlay2)"
    docker network ls >/dev/null 2>&1 && ok "docker networks listables"
  else
    fail "docker daemon no responde (¿servicio arriba?)"
  fi
else
  fail "docker no instalado"
fi

# 4) OVS
command -v ovs-vsctl >/dev/null 2>&1 && ok "ovs-vsctl: $(ovs-vsctl --version | head -1)" || warn "openvswitch-switch no instalado (apt install)"
command -v ovs-ofctl >/dev/null 2>&1 && ok "ovs-ofctl disponible"
# prueba funcional: crea y borra un bridge sin tocar datos existentes
if command -v ovs-vsctl >/dev/null 2>&1; then
  if sudo -n ovs-vsctl add-br __preflight_br0 >/dev/null 2>&1; then
    BR_OK=0; sudo -n ovs-vsctl del-br __preflight_br0 >/dev/null 2>&1 || true
    ok "OVS puede crear/borrar bridges"
  else
    fail "OVS no puede crear bridge (probar sin sudo o revisar datapath)"
  fi
fi

# 5) Namespaces (necesarios para containers con red)
if unshare -rm true 2>/dev/null; then ok "unshare user+net OK"; else fail "unshare bloqueado (seccomp/userns)"; fi

# 6) Recursos
MEM_MB="$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)"
DISK_GB="$(df -BG / | awk 'NR==2{gsub("G","",$4); print $4}')"
CPU_N="$(nproc)"
[ "$MEM_MB" -ge 8192 ] && ok "RAM disponible: ${MEM_MB}MiB" || warn "RAM disponible: ${MEM_MB}MiB (recomendado ≥8GiB)"
[ "$DISK_GB" -ge 20 ] && ok "Disco libre: ${DISK_GB}G" || warn "Disco libre: ${DISK_GB}G (recomendado ≥20G)"
[ "$CPU_N" -ge 4 ] && ok "CPUs: $CPU_N" || warn "CPUs: $CPU_N"

# 7) Puertos del lab
for p in 3080 5000 5001 5002 5003 5004 5005 6653 1194 3000; do
  if ss -lnt "( sport = :$p )" 2>/dev/null | grep -q ":$p"; then
    warn "puerto $p ya en uso"
  fi
done

echo
echo "Resumen: PASS=$PASS FAIL=$FAIL WARN=$WARN"
if [ "$FAIL" -gt 0 ]; then
  echo "DECISION: NO-GO (corregir FAIL arriba)"
  exit 1
else
  echo "DECISION: GO"
  exit 0
fi
