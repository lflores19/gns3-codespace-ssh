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

| Operation | Method & Endpoint | Payload / Parameters |
| --- | --- | --- |
| **Check Version** | `GET /version` | None |
| **List Projects** | `GET /projects` | None |
| **Create Project** | `POST /projects` | `{"name": "Topology-Name"}` |
| **Open Project** | `POST /projects/{project_id}/open` | None |
| **Create Node** | `POST /projects/{project_id}/nodes` | `{"name": "R1", "node_type": "dynamips|vpcs|qemu|ethernet_switch", "compute_id": "local", "x": 0, "y": 0, "properties": {...}}` |
| **Create Link** | `POST /projects/{project_id}/links` | `{"nodes": [{"node_id": "...", "adapter_number": 0, "port_number": 0}, {"node_id": "...", "adapter_number": 0, "port_number": 0}]}` |
| **Start Node** | `POST /projects/{project_id}/nodes/{node_id}/start` | None |
| **Start All Nodes** | `POST /projects/{project_id}/nodes/start` | None |
| **Stop All Nodes** | `POST /projects/{project_id}/nodes/stop` | None |
| **Get Node Console** | `GET /projects/{project_id}/nodes/{node_id}` | Returns `console` (port number) and `console_type` |

## Automated Topology Creation Script (Python Template)

```python
import requests
import json
import time

GNS3_URL = "http://127.0.0.1:3080/v2"

def create_topology():
    # 1. Create or load project
    proj_resp = requests.post(f"{GNS3_URL}/projects", json={"name": "AutoLab-Enterprise"})
    if proj_resp.status_code == 201:
        project = proj_resp.json()
    else:
        # Get existing
        projects = requests.get(f"{GNS3_URL}/projects").json()
        project = next(p for p in projects if p["name"] == "AutoLab-Enterprise")
        requests.post(f"{GNS3_URL}/projects/{project['project_id']}/open")
    
    project_id = project["project_id"]
    print(f"[+] Active Project: {project['name']} ({project_id})")

    # 2. Add VPCS Nodes
    pc1 = requests.post(f"{GNS3_URL}/projects/{project_id}/nodes", json={
        "name": "PC-1", "node_type": "vpcs", "compute_id": "local", "x": -200, "y": 0
    }).json()

    pc2 = requests.post(f"{GNS3_URL}/projects/{project_id}/nodes", json={
        "name": "PC-2", "node_type": "vpcs", "compute_id": "local", "x": 200, "y": 0
    }).json()

    # 3. Add Switch
    sw1 = requests.post(f"{GNS3_URL}/projects/{project_id}/nodes", json={
        "name": "SW-Core", "node_type": "ethernet_switch", "compute_id": "local", "x": 0, "y": 0
    }).json()

    # 4. Link PC1 <-> Switch (port 0) and PC2 <-> Switch (port 1)
    requests.post(f"{GNS3_URL}/projects/{project_id}/links", json={
        "nodes": [
            {"node_id": pc1["node_id"], "adapter_number": 0, "port_number": 0},
            {"node_id": sw1["node_id"], "adapter_number": 0, "port_number": 0}
        ]
    })
    requests.post(f"{GNS3_URL}/projects/{project_id}/links", json={
        "nodes": [
            {"node_id": pc2["node_id"], "adapter_number": 0, "port_number": 0},
            {"node_id": sw1["node_id"], "adapter_number": 0, "port_number": 1}
        ]
    })

    # 5. Start all nodes
    requests.post(f"{GNS3_URL}/projects/{project_id}/nodes/start")
    print("[+] Topology created and started successfully!")

if __name__ == "__main__":
    create_topology()
```

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
