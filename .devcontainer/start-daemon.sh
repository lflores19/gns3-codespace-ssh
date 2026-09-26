#!/usr/bin/env bash
# Arranque postStart: GNS3
set -e

UBRIDGE_SOURCE=/usr/bin/ubridge
UBRIDGE_TARGET=/home/vscode/.local/bin/ubridge-uncap

if [[ ! -r "$UBRIDGE_SOURCE" ]]; then
  echo "Missing or unreadable uBridge binary: $UBRIDGE_SOURCE" >&2
  exit 1
fi

# Do not preserve file capabilities: Codespaces lacks CAP_NET_ADMIN in its
# bounding set, while GNS3's QEMU/VPCS UDP links work without TAP or OVS.
install -Dm755 "$UBRIDGE_SOURCE" "$UBRIDGE_TARGET"
install -Dm755 /usr/bin/dynamips /home/vscode/.local/bin/dynamips-uncap
if [[ ! -x "$UBRIDGE_TARGET" ]]; then
  echo "Failed to create required unprivileged uBridge: $UBRIDGE_TARGET" >&2
  exit 1
fi

mkdir -p /home/vscode/GNS3 /home/vscode/.config/GNS3/2.2

# Relink GNS3 state dirs to the persistent /workspaces volume. Codespaces
# keeps /workspaces across container rebuilds while /home is ephemeral
# overlay. The base image seeds empty dirs (e.g. images/IOS, images/QEMU):
# merge copy-missing files into the persistent tree, then replace with a
# symlink. Refuse only when a non-empty dir cannot be fully merged.
PERSIST_ROOT=/workspaces/.gns3-data/GNS3
# GNS3 config (incl. templates in gns3_controller.conf) also lives under /home and
# is lost on rebuild. The persistent copy is authoritative: replace the
# on-image dir with a symlink, then drop the repo's gns3_server.conf on top.
CFG_PERSIST=/workspaces/.gns3-data/home-vscode-config-GNS3
if [[ -d "$CFG_PERSIST" ]]; then
  if [[ -L /home/vscode/.config/GNS3 ]]; then
    ln -sfn "$CFG_PERSIST" /home/vscode/.config/GNS3
  else
    rm -rf /home/vscode/.config/GNS3 && ln -s "$CFG_PERSIST" /home/vscode/.config/GNS3\
      && echo "GNS3 config relinked to persistent volume"
  fi
fi
for d in images projects appliances symbols configs; do
  src="/home/vscode/GNS3/$d"
  dst="$PERSIST_ROOT/$d"
  if [[ -d "$dst" ]]; then
    if [[ -L "$src" ]]; then
      ln -sfn "$dst" "$src"
    elif [[ ! -e "$src" ]]; then
      ln -s "$dst" "$src"
    elif [[ -d "$src" ]]; then
      conflict=0
      while IFS= read -r -d '' f; do
        rel="${f#./}"
        if [[ -f "$dst/$rel" ]]; then
          cmp -s "$f" "$dst/$rel" || { echo "WARNING: conflict $src/$rel vs $dst/$rel; keeping $src" >&2; conflict=1; }
        else
          mkdir -p "$dst/$(dirname "$rel")" && cp -a "$f" "$dst/$rel"
        fi
      done < <(cd "$src" && find . -type f -print0)
      if [[ "$conflict" -eq 0 ]]; then
        rm -rf "$src" && ln -s "$dst" "$src"
      fi
    fi
  else
    mkdir -p "$src"
  fi
done

cp -f "$(pwd)/.devcontainer/gns3_server.conf" /home/vscode/.config/GNS3/2.2/gns3_server.conf
if ! pgrep -f gns3server >/dev/null 2>&1; then
  nohup gns3server --config /home/vscode/.config/GNS3/2.2/gns3_server.conf >/tmp/gns3server.log 2>&1 &
fi

echo "=== GNS3 Ready ==="
