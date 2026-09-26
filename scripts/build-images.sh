#!/usr/bin/env bash
# build-images.sh — compila solo lo que existe y fija tags versionados.
set -Eeuo pipefail

TAG="${TAG:-1.0.0}"
DIRS=(docker/app docker/web docker/db docker/dhcp docker/dns docker/ids docker/samba docker/vpn controller)
FAILED=()

echo "[*] build-images tag=$TAG"
cd "$(dirname "$0")/.."

build_one() {
  local d="$1"; local name="lab-$(basename "$d"):${TAG}"
  if [ -f "$d/Dockerfile" ]; then
    echo "[*] build $name  <- $d"
    docker build -t "$name" "$d" || { FAILED+=("$name"); return 1; }
  else
    echo "[skip] $d (no Dockerfile)"
  fi
}

for d in "${DIRS[@]}"; do build_one "$d" || true; done

echo
echo "== Resultado =="
docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}' | grep '^lab-' || true

if [ "${#FAILED[@]}" -gt 0 ]; then
  echo "FALLOS: ${FAILED[*]}" >&2
  exit 1
fi

# regla anti-latest: documentamos las imágenes efectivas
docker image inspect $(docker images -q 'lab-*') --format '{{.RepoTags}} {{.Id}}' | sort -u || true
