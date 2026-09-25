#!/usr/bin/env bash
set -euo pipefail
for d in docker/*; do
  [ -f "$d/Dockerfile" ] || continue
  name="lab-$(basename "$d")"; tag="$name:latest"
  echo "[*] building $tag"
  docker build -t "$tag" "$d" | tee -a build.log
done
echo "[✓] builds completos (log en build.log)"
