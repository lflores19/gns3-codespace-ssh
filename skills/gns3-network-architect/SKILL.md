---
name: gns3-network-architect
description: "Trigger: gns3, gns3 topology, gns3 api, gns3 server, gns3 architecture, cisco dynamips, vpcs, qemu network, network simulation, diseno de red gns3, topologia gns3. Design, automate, and orchestrate network topologies, links, IP schemes, routing protocols, and node configurations via GNS3 REST API v2 and automated scripting."
license: Apache-2.0
metadata:
  author: gentleman-programming
  version: "1.0"
---

## Activation Contract

Use this skill when designing, generating, automating, or configuring network topologies and architectures inside GNS3 (via REST API v2, Python automation, or CLI).

## GNS3 REST API v2 Contract

Base URL: `http://<gns3-host>:3080/v2`

> **CRITICAL:** QEMU and Dynamips appliances MUST be fetched via `template_id` (from `GET /templates` or `GET /qemu/vms` / `GET /dynamips/vms`) and created via `POST /templates/{template_id}` inside the target project. Direct `POST /nodes` with `qemu|dynamips` will fail without a fully populated server configuration block. VPCS and built-in Ethernet Switches can be created directly via `POST /nodes`.

| Operation | Method & Endpoint | Payload / Parameters |
| --- | --- | --- |
| **Check Version** | `GET /version` | None |
| **List Projects** | `GET /projects` | None |
| **Create Project** | `POST /projects` | `{"name": "Topology-Name"}` |
| **Open Project** | `POST /projects/{project_id}/open` | None |
| **Create Built-in Node** | `POST /projects/{project_id}/nodes` | `{"name": "PC-1", "node_type": "vpcs|ethernet_switch|cloud|nat", "compute_id": "local", "x": 0, "y": 0}` |
| **Boolean Fetch Templates** | `GET /templates` | None |
| **Add Template Node** | `POST /projects/{project_id}/templates/{template_id}` | `{"x": 0, "y": 0, "compute_id": "local", "name": "R1"}` |
| **Create Link** | `POST /projects/{project_id}/links` | `{"nodes": [{"node_id": "...", "adapter_number": 0, "port_number": 0}, {"node_id": "...", "adapter_number": 0, "port_number": 0}]}` |
| **Start Node** | `POST /projects/{project_id}/nodes/{node_id}/start` | None |
| **Start All Nodes** | `POST /projects/{project_id}/nodes/start` | None |
| **Stop All Nodes** | `POST /projects/{project_id}/nodes/stop` | None |
| **Get Node Console** | `GET /projects/{project_id}/nodes/{node_id}` | Returns `console` (port number) and `console_type` |

## Automated Topology Creation Script (Python Template)

For robust multi-node architecture, use the official `gns3fy` library (`pip install gns3fy`):

```python
import gns3fy

GNS3_URL = "http://127.0.0.1:3080"
project_name = "AutoLab-Enterprise"

# 1. Connect and Open/Create Project
server = gns3fy.Gns3Connector(GNS3_URL)
try:
    project = gns3fy.Project(name=project_name, connector=server)
    project.get()
    project.open()
except:
    project = gns3fy.Project(name=project_name)
    project.create(connector=server)
    project.get()

print(f"[+] Active Project: {project.name} ({project.project_id})")

# 2. Add VPCS Nodes
pc1 = gns3fy.Node(name="PC-1", node_type="vpcs", compute_id="local", x=-200, y=0, project_id=project.project_id, connector=server)
pc1.create()

# 3. Add QEMU / Dynamips Node via Template
# Get template ID
server.get_templates()
template = next(t for t in server.templates if "c7200" in t["name".lower()])
router1 = gns3fy.Node(
    name="R1",
    project_id=project.project_id,
    connector=server,
    node_type="dynamips",
    x=0, y=0
)
# Add using template
router1.create(template_id=template["template_id"])

# 4. Link PC1 <-> Router1
link = gns3fy.Link(
    project_id=project.project_id,
    connector=server,
    nodes=[
        {"node_id": pc1.node_id, "adapter_number": 0, "port_number": 0},
        {"node_id": router1.node_id, "adapter_number": 0, "port_number": 0}
    ]
)
link.create()

# 5. Start all nodes
project.open()
for node in project.nodes:
    node.start()

print("[+] Topology created and started successfully!")
```

*Alternative Minimal Python (Raw Requests) Template is available in the Reference section below.*

## Architecture Design Standards & Image Provisioning

- **Addressing Standards**:
  - Loopback: `/32` (e.g., `10.255.255.X/32`) for Router IDs and BGP peering.
  - Core/P2P Transit Links: `/30` or `/31` (e.g., `10.0.X.Y/30`).
  - Access LAN: `/24` / `/28` (e.g., `192.168.X.0/24`).
- **Protocols**: OSPF Area 0 interconnecting ABRs; iBGP Route Reflectors using Loopbacks + IGP re-distribution. Passive interfaces on edge interfaces.
- **Firmware / Images**: Dynamips requires Cisco IOS `.image` (especially c7200). QEMU requires `.qcow2` or `.img`. IOU requires L2/L3 `.bin`. Use the `gns3-codespace-ops` skill to place them in `/home/vscode/GNS3/images/<category>/` so they appear in Templates.

## VPCS Automated Configuration via Telnet

To configure IP addresses on VPCS nodes automatically:

```python
import telnetlib
import time

def configure_vpcs(host, port, ip_cidr, gateway):
    tn = telnetlib.Telnet(host, port, timeout=10)
    time.sleep(1)
    tn.write(b"\r\n")
    time.sleep(0.5)
    # Set IP
    cmd = f"ip {ip_cidr} {gateway}\r\n".encode("ascii")
    tn.write(cmd)
    time.sleep(1)
    tn.write(b"show ip\r\n")
    time.sleep(0.5)
    output = tn.read_very_eager().decode("utf-8", errors="ignore")
    tn.close()
    return output
```

## Cisco IOS Architecture & Routing Guidelines

1. **Addressing Standard**:
   - Loopback Interfaces: `/32` (e.g. `10.255.255.X/32` for Router ID & BGP peering).
   - Point-to-Point Links: `/30` or `/31` (e.g. `10.0.X.Y/30`).
   - LAN / Access Segments: `/24` or `/28` (e.g. `192.168.X.0/24`).
2. **Dynamic Routing Protocols**:
   - **OSPF Single/Multi-Area**: Area 0 (Backbone) connecting all ABRs. Passive interfaces on edge/LAN ports.
   - **BGP (eBGP & iBGP)**: iBGP mesh with Route Reflectors (RR) using Loopbacks + IGP synchronization.
3. **QEMU / Appliance Emulation**:
   - In cloud/Codespaces environments without hardware KVM, always set `require_kvm: false` and use lightweight network appliances (Alpine Linux, VPCS, OpenWRT, Cisco IOU/Dynamips c7200/c3725) to avoid CPU bottlenecks.
