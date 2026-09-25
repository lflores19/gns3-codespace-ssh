#!/usr/bin/env bash
set -e

echo "=== GNS3 Codespace Setup ==="

# Copy server configuration to default user config directory
mkdir -p /home/vscode/.config/GNS3/2.2
cp -f .devcontainer/gns3_server.conf /home/vscode/.config/GNS3/2.2/gns3_server.conf

# Ensure directories exist with proper permissions
mkdir -p /home/vscode/GNS3/projects \
         /home/vscode/GNS3/images/QEMU \
         /home/vscode/GNS3/images/IOS \
         /home/vscode/GNS3/appliances

# Generate SSH host keys if missing
sudo ssh-keygen -A 2>/dev/null || true

# Set up vscode user SSH directory if needed
mkdir -p /home/vscode/.ssh
chmod 700 /home/vscode/.ssh

echo "=== GNS3 Setup Complete ==="
