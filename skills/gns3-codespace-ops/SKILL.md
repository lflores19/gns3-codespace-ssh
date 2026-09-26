---
name: gns3-codespace-ops
description: "Trigger: gns3 codespace, gns3 daemon, gns3 ssh, gns3 remote server, gns3 codespaces ops, gns3 troubleshooting. Manage lifecycle, remote port forwarding, daemon operations, and image/appliance provisioning for GNS3 Server running inside GitHub Codespaces."
license: Apache-2.0
metadata:
  author: gentleman-programming
  version: "1.0"
---

## Activation Contract

Use this skill when administering, troubleshooting, port-forwarding, or provisioning appliances for GNS3 Server running in GitHub Codespaces.

## Remote Codespace Connection Matrix

| Need | Command |
| --- | --- |
| **Interactive SSH Shell** | `gh codespace ssh -c <codespace-name>` |
| **Forward GUI & Console Ports** | `gh codespace ports forward 3080:3080 5000:5000 5001:5001 5002:5002 5003:5003 5004:5004 5005:5005 -c <codespace-name>` |
| **Direct SSH Background Tunnel** | `gh codespace ssh -c <codespace-name> -- -N -L 3080:localhost:3080 -L 5000:localhost:5000 -L 5001:localhost:5001 -L 5002:localhost:5002 -L 5003:localhost:5003` |
| **Check Codespace Status** | `gh codespace view -c <codespace-name> --json state,idleTimeoutMinutes` |

## GNS3 Daemon Ops & Maintenance

Inside the Codespace (`/home/vscode`):

```bash
# 1. Check GNS3 Daemon & Logs
ps aux | grep gns3server
cat /tmp/gns3server.log

# 2. Restart Server Daemon cleanly
pkill -f gns3server || true
nohup gns3server --config /home/vscode/.config/GNS3/2.2/gns3_server.conf > /tmp/gns3server.log 2>&1 &

# 3. Test API Health locally
curl -s http://127.0.0.1:3080/v2/version
```

## Provisioning Images & Appliances

Upload images directly into the persistent GNS3 directory:

- **Dynamips Cisco IOS (.image / .bin)**: `/home/vscode/GNS3/images/IOS/`
- **QEMU (.qcow2 / .img / .iso)**: `/home/vscode/GNS3/images/QEMU/`
- **GNS3 Appliance templates (.gns3a)**: `/home/vscode/GNS3/appliances/`

```bash
# Example: Download Alpine Linux appliance for ultra-lightweight routing/testing
wget -P /home/vscode/GNS3/images/QEMU/ https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/x86_64/alpine-virt-3.18.4-x86_64.iso

# Verify downloaded images match expected binary sizes
ls -lh /home/vscode/GNS3/images/IOS/ /home/vscode/GNS3/images/QEMU/
```

## Security Hardening for Public DevContainers

When the Codespace is shared, the URL is public, or `3080` is exposed via Port Forward:
1. **Enable Web Auth** in `gns3_server.conf` (requires GNS3 WebUI/Server 2.2.43+):
   ```ini
   [Server]
   host = 0.0.0.0
   port = 3080
   allow_remote_console = True
   console_start_port_range = 5000
   console_end_port_range = 5050
   
   # Auth settings
   user = admin
   password = <SET_A_UNIQUE_SECRET_OUTSIDE_THE_REPOSITORY>
   ```
> Never commit credentials; set a unique secret outside the repository.

2. **Restart the daemon**: `pkill -f gns3server; nohup gns3server --config /home/vscode/.config/GNS3/2.2/gns3_server.conf > /tmp/gns3server.log 2>&1 &`
3. **Remote Clients**: Connect GNS3 GUI to `http://127.0.0.1:3080` using Basic Auth, or bind HTTP to codespace's proxy via `gh codespace ports visibility 3080:private`.

## Diagnostics & Troubleshooting

| Symptom | Cause | Solution |
| --- | --- | --- |
| `Permission denied on /usr/bin/ubridge` | Missing Linux capabilities | Codespaces lacks CAP_NET_ADMIN in the bounding set, so `setcap` on the shipped binary does NOT help. GNS3 runs as `vscode` (no exec right on group-only ubridge anyway). Use an uncap copy: `install -Dm755 /usr/bin/ubridge ~/.local/bin/ubridge-uncap` and set `ubridge_path` under `[Server]` in gns3_server.conf. Enables QEMU/VPCS UDP links only — TAP/OVS bridging stays unavailable. |
| `[Errno 1] Operation not permitted: '/usr/bin/dynamips'` when creating an Ethernet switch node | `/usr/bin/dynamips` carries `cap_net_admin,cap_net_raw=ep` | Same uncap cure: `install -Dm755 /usr/bin/dynamips ~/.local/bin/dynamips-uncap` and set `dynamips_path` under `[Dynamips]` in gns3_server.conf, then restart gns3server. |
| `Cannot connect to 127.0.0.1:3080` | Port forward inactive or daemon down | Re-run `gh codespace ports forward` and verify `ps aux \| grep gns3server` |
| `Console connection refused on port 5000` | Node not started or port outside range | Check `gns3_server.conf` has `allow_remote_console = True` and start the node via API/GUI. |
| `CPU at 100% on router boot` | Dynamips Idle-PC not calculated | In GNS3 GUI, right-click router -> **Idle-PC** calculation to stabilize CPU usage. |
