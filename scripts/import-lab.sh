#!/usr/bin/env bash
# import-lab.sh — import a portable GNS3 topology bundle into a fresh Codespace.
# Runs INSIDE the destination Codespace. Usage:
#   ./scripts/import-lab.sh /workspaces/gns3-codespace-ssh/export/utp-network-lab-export-XXXX.tar.gz
set -euo pipefail

BUNDLE="${1:-}"
[ -f "$BUNDLE" ] || { echo "Uso: $0 <ruta-al-export.tar.gz>" >&2; exit 1; }

GNS3_DIR="/home/vscode/GNS3"
TARGET_ROOT="$GNS3_DIR/projects"
mkdir -p "$TARGET_ROOT"

# Integrity check when sidecar hash exists.
if [ -f "$BUNDLE.sha256" ]; then
  (cd "$(dirname "$BUNDLE")" && sha256sum -c "$(basename "$BUNDLE").sha256")
fi

STAGE="$(mktemp -d)"
tar -xzf "$BUNDLE" -C "$STAGE"

PID_DIR="$(find "$STAGE" -mindepth 1 -maxdepth 1 -type d | head -1)"
[ -n "$PID_DIR" ] || { echo "ERROR: bundle sin directorio de proyecto" >&2; exit 1; }
PID="$(basename "$PID_DIR")"
DEST="$TARGET_ROOT/$PID"
if [ -e "$DEST" ]; then
  echo "ERROR: $DEST ya existe; no se sobreescribe. Elegí un Codespace limpio." >&2
  exit 1
fi
cp -a "$PID_DIR" "$DEST"
echo "[+] Proyecto importado a $DEST"
echo "[i] Reiniciá gns3server y abrí el proyecto desde la API o GUI."
echo "[i] Recordá: no incluye imágenes qcow2 ni secretos; generá credenciales nuevas."
