#!/usr/bin/env bash
# gen-pki.sh — genera CA + servidor + cliente OpenVPN con easy-rsa (modo lab).
# Escriba en ./pki (gitignored). Nunca commitear claves.
set -Eeuo pipefail
OUT="${1:-./pki}"
mkdir -p "$OUT"
if ! command -v easyrsa >/dev/null 2>&1; then
  echo "instalar easy-rsa primero: apt install easy-rsa"; exit 1
fi
cd "$OUT"
easyrsa init-pki 2>/dev/null || true
echo "lab" | easyrsa build-ca nopass
easyrsa build-server-full server nopass
easyrsa build-client-full cliente1 nopass
easyrsa gen-dh
openvpn --genkey secret ta.key
ls -1 . pki/private pki/issued 2>/dev/null | head -20
