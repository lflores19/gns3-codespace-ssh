#!/usr/bin/env bash
# export-lab.sh — export portable GNS3 topology (no disk images, no secrets).
# Runs INSIDE the Codespace. Usage:
#   ./scripts/export-lab.sh [project_name] [output_dir]
set -euo pipefail

PROJECT="${1:-utp-network-lab}"
OUTDIR="${2:-/workspaces/gns3-codespace-ssh/export}"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
BUNDLE="utp-network-lab-export-${TS}.tar.gz"
GNS3_DIR="/home/vscode/GNS3"
API="http://127.0.0.1:3080/v2"

mkdir -p "$OUTDIR" /tmp/lab-export

echo "[*] Resolving project: $PROJECT"
PROJ_JSON="$(curl -fsS "$API/projects")"
PID="$(printf '%s' "$PROJ_JSON" | python3 -c 'import sys,json;p=[x for x in json.load(sys.stdin) if x["name"]==sys.argv[1]];print(p[0]["project_id"] if p else "")' "$PROJECT")"
[ -n "$PID" ] || { echo "ERROR: project '$PROJECT' not found via API" >&2; exit 1; }

SRC="$GNS3_DIR/projects/$PID"
[ -d "$SRC" ] || { echo "ERROR: project dir not found: $SRC" >&2; exit 1; }

STAGE=/tmp/lab-export/$PID
rm -rf "$STAGE"; mkdir -p "$STAGE"

echo "[*] Copying portable files (excluding qcow2/img disks)"
# Portable only: .gns3 topology + project metadata, NOT disk images.
(cd "$SRC" && find . -maxdepth 4 \( -name '*.gns3' -o -name '*.json' -o -name '*.conf' -o -name '*.txt' -o -name '*.vpc' -o -name '*.nvram' \) \
  ! -name '*.qcow2' ! -name '*.img' ! -name '*.iso' -exec cp --parents "{}" "$STAGE" \;)

echo "[*] Capturing API references"
curl -fsS "$API/projects/$PID" >"$STAGE/api-project.json"
curl -fsS "$API/projects/$PID/nodes" >"$STAGE/api-nodes.json"
curl -fsS "$API/projects/$PID/links" >"$STAGE/api-links.json"

tar -C /tmp/lab-export -czf "$OUTDIR/$BUNDLE" "$PID"
sha256sum "$OUTDIR/$BUNDLE" >"$OUTDIR/$BUNDLE.sha256"
echo "[+] Export listo: $OUTDIR/$BUNDLE"
echo "[i] Esto NO incluye imágenes qcow2 ni secretos; ver docs/deploy-en-otra-cuenta.md."
