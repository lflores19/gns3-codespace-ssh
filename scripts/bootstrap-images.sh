#!/usr/bin/env bash
# bootstrap-images.sh — recreate the Alpine base qcow2 needed by the lab.
# Runs INSIDE the Codespace. Idempotent: skips if image already exists.
set -euo pipefail

IMG_DIR="/workspaces/.gns3-data/GNS3/images/QEMU"
[ -d "$IMG_DIR" ] || IMG_DIR="/home/vscode/GNS3/images/QEMU"
ISO_URL="https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/x86_64/alpine-virt-3.22.6-x86_64.iso"
ISO="$IMG_DIR/alpine-virt-3.22.6-x86_64.iso"
BASE="$IMG_DIR/alpine-virt-3.22.6-installed-base.qcow2"

mkdir -p "$IMG_DIR"
if [ -f "$ISO" ]; then
  echo "[*] ISO ya existe: $ISO"
else
  echo "[*] Descargando $ISO_URL"
  curl -fL --retry 3 -o "$ISO" "$ISO_URL"
fi

if [ -f "$BASE" ]; then
  echo "[*] Imagen base ya existe: $BASE"
else
  echo "[*] Creando qcow2 base 8G"
  qemu-img create -f qcow2 "$BASE" 8G
  echo "[i] Instalá Alpine desde la ISO (boot interactivo con QEMU o GNS3), luego apagá y mantené $BASE como imagen read-only de referencia."
  echo "[i] Comando típico de instalación offline/slirp (ver docs/estado.md):"
  echo "    qemu-system-x86_64 -m 512 -drive file=$BASE,format=qcow2 -cdrom $ISO -boot d -nic user,model=virtio-net-pci -display none -serial telnet:127.0.0.1:5000,server,nowait"
fi
echo "[+] bootstrap-images listo"
