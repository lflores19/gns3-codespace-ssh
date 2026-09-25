#!/usr/bin/env bash
echo "=== Test de aceptación ==="
echo "[1] NET01 DHCP ping VLANs... (manual)"
ping -c1 192.168.10.1 2>/dev/null && echo "OK10" || echo "FALLO VLAN10"
ping -c1 192.168.20.1 2>/dev/null && echo "OK20" || echo "FALLO VLAN20"
ping -c1 192.168.40.1 2>/dev/null && echo "OK40" || echo "FALLO VLAN40"
