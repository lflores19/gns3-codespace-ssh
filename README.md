# GNS3 Codespace enterprise-network lab

This repository documents the observed GNS3 lab running in a Codespace. It is a QEMU/Dynamips/VPCS lab—not a functional Docker, OVS, or OpenFlow deployment. The persisted project is `utp-network-lab` (`e792c7b3-8a50-4d0b-a93a-ab64e7e6e344`).

> **Retired entrypoints — do not run:** `scripts/build.sh`, `scripts/start-lab.sh`, and `scripts/provision-phase2.sh` are legacy Docker/provisioning paths. Use `.devcontainer` setup/start-daemon and the current QEMU runbook instead. `scripts/test-lab.sh` is not evidence that the current lab is proven.

## Quick path: inspect the persisted project

Use the GNS3 API against the already persisted project; do **not** run fictional build or create scripts. From the Codespace where `gns3server` is running:

```bash
export GNS3_API=http://127.0.0.1:3080/v2
export PROJECT_ID=e792c7b3-8a50-4d0b-a93a-ab64e7e6e344

curl -fsS "$GNS3_API/version"
curl -fsS "$GNS3_API/projects/$PROJECT_ID"
curl -fsS "$GNS3_API/projects/$PROJECT_ID/nodes"
```

After confirming the project and node list, start only the node(s) you intend to use through the API, then re-read their state:

```bash
curl -fsS -X POST "$GNS3_API/projects/$PROJECT_ID/nodes/<node-id>/start"
curl -fsS "$GNS3_API/projects/$PROJECT_ID/nodes/<node-id>"
```

Node and link identifiers are recorded in [`evidence/utp-lab-ids.json`](evidence/utp-lab-ids.json). API access does not expose or require guest credentials; do not put passwords, VPN keys, or PATs in this repository.

## Observed runtime

| Area | Observed implementation |
|---|---|
| Platform | GNS3 2.2.55 in Codespaces; QEMU runs with TCG (no KVM). |
| Switching | Two Dynamips `EtherSwitch` nodes (`sw1`, `sw2`) joined by an 802.1Q trunk. |
| Routing | QEMU Alpine `fw1` is the router-on-a-stick gateway and trunk endpoint. |
| Guests | Alpine QEMU: `web1` (`172.16.0.20`), `client1` (`172.16.0.21`), `admin-vm` (VLAN 20), `wan-vpn` (VLAN 300), and `mon1` (`172.16.0.30`). |
| Clients | VPCS nodes cover the VLAN access hosts, including VLANs 10, 20, 40, 99, and 300. |
| Services with evidence | `fw1` provides routing, filtering, DHCP/DNS and the WireGuard endpoint; `web1` provides the demonstrated HTTP and SMB services; `client1` runs the Flask/Gunicorn inventory application on `:5000`; `mon1` runs PostgreSQL 16 on `:5432` alongside the documented monitoring stack. |

`client1` (`172.16.0.21`) uses persistent SCRAM role `inventory_app` to reach PostgreSQL 16 on `mon1` (`172.16.0.30`). [`evidence/APP01-crud.txt`](evidence/APP01-crud.txt) records inventory persistence through DB and app restarts; [`evidence/DB01-isolation.txt`](evidence/DB01-isolation.txt) records the allowed client, a rejected `.20` client, and invalid-password rejection. PostgreSQL HBA source restriction is L3 policy on a shared L2 DMZ, not firewall isolation; IP spoofing and compromise of `client1` are outside its guarantee. Credentials and three private qcow2 backups remain outside the repository.

## Network map

| VLAN | Name | Subnet | Gateway on `fw1` | Observed role |
|---:|---|---|---|---|
| 10 | ventas | `192.168.10.0/24` | `192.168.10.1` | Sales access hosts |
| 20 | administracion | `192.168.20.0/24` | `192.168.20.1` | `admin-vm` and administration |
| 40 | invitados | `192.168.40.0/24` | `192.168.40.1` | Guest access host |
| 99 | gestion | `192.168.99.0/24` | `192.168.99.1` | Management access host |
| 200 | dmz | `172.16.0.0/24` | `172.16.0.1` | `web1`, `client1`, and `mon1` |
| 300 | wan | `10.20.30.0/24` | `10.20.30.1` | `wan-vpn` and WAN access host |

## Scope and platform limits

- Codespaces lacks the capabilities needed for usable Docker networking, OVS datapaths, TAP/bridges, and OpenFlow. Docker-node builds, OVS switches, and SDN/OpenFlow claims are out of scope for this runtime.
- VPN01 is evidenced for the QEMU WAN peer, including permitted DMZ access and denied management access; a Windows VPN client was not evaluated.
- Versioned snapshots [`config/firewall/fw.nft`](config/firewall/fw.nft) and [`config/dns/lab.conf`](config/dns/lab.conf) record the observed firewall and DNS configuration. They do not automatically rebuild or update guest qcow2 disks.
- PERF01 was explicitly skipped. Do not interpret point-in-time resource observations as a performance test.
- The acceptance matrix remains the authority for requirement status; this README and [`config/lab.yaml`](config/lab.yaml) are documentation, not a source of runtime truth.

## Evidence and status

The acceptance matrix records 15 `PASS` requirements out of 22, including NET01 DHCP renewal, NET02's active `fw1:eth0`↔`sw2:E7` dot1q capture with VLAN tags 10/20/40/99/200/300 and 3/3 control pings, NET04 guest isolation, SEC01 representative firewall and IPv6-bypass controls, and IDS01. IDS01 uses a same-guest `tc clsact` ingress software mirror from `fw1:eth0` to `mirror0`; a second Suricata instance produced the `allowed` VLAN20 `admin-vm`→`web1:445` EVE SID `1000002` alert and matching PCAP while the original `eth0` sensor remained active. [`evidence/IDS01-mirror.txt`](evidence/IDS01-mirror.txt), [`evidence/IDS01-eve.json`](evidence/IDS01-eve.json), and [`evidence/IDS01-mirror.pcap`](evidence/IDS01-mirror.pcap) record the initial test with `tc` dropped `0`; [`evidence/IDS01-reboot.txt`](evidence/IDS01-reboot.txt) and [`evidence/IDS01-reboot.pcap`](evidence/IDS01-reboot.pcap) record the matching post-restart test after `/etc/local.d/ids-mirror.start` restored the mirror and sensor. This is not physical switch SPAN, an independent sensor VM, or evidence for same-VLAN flows that bypass `fw1`. NET02 evidence is [`evidence/NET02-trunk.txt`](evidence/NET02-trunk.txt) and the preserved 220278-byte PCAP [`evidence/NET02-fw1-trunk.pcap`](evidence/NET02-fw1-trunk.pcap) (SHA-256 `4c72711aa2421c30c2ae277d590b342510b9da37c93d6d3021f539bbf3832dba`); some frames are untagged, so not every frame is claimed tagged. Read [`docs/estado.md`](docs/estado.md) for the chronology, platform constraints, and bounded test outcomes; these representative flows do not exhaust every policy port combination. [`docs/informe.md`](docs/informe.md) summarizes accepted requirements and limitations. [`evidence/utp-lab-ids.json`](evidence/utp-lab-ids.json) contains the persisted project inventory used by the API quick path.

## Versioned snapshots and future work

`config/lab.yaml` records the observed inventory and versioned configuration snapshots. These repository snapshots are not a GNS3 export and do not rebuild guest qcow2 disks automatically; reconcile them with the live API and evidence before operating on the project or claiming deployment. Future work remains planning input only.
