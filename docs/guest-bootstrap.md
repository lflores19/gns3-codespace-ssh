# Guest bootstrap — recrear idéntico (salvo secretos) en un Codespace limpio

Este runbook cierra los gaps del clone puro: templates QEMU, configs de VPCS/Dynamips, imágenes base y services dentro de cada guest. Orden recomendado.

## 0) Prerequisitos

- Codespace nuevo desde el repo (devcontainer corre `setup.sh`; `start-daemon.sh` religa `/workspaces/.gns3-data`).
- Ejecutar `scripts/bootstrap-images.sh` para tener `alpine-virt-3.22.6-installed-base.qcow2` y el ISO.
- Registrar el template QEMU de Alpine en el daemon (si vino exportado, importá con `scripts/import-lab.sh` primero).

## 1) Topología (portable)

- `scripts/export-lab.sh` en origen → `utp-network-lab-export-*.tar.gz` (incluye `.gns3`, API refs, `startup.vpc` de VPCS y `.nvram` de Dynamips).
- `scripts/import-lab.sh` en destino (Codespace limpio; no sobreescribe).

## 2) Guests QEMU — qué corre dónde

| Guest | IP | Rol | Config aplicable |
|---|---|---|---|
| `fw1` | gateways .1 por VLAN | router-on-a-stick | `config/firewall/fw.nft`, `config/dns/lab.conf`, `config/ids/mirror.yaml` |
| `web1` | 172.16.0.20 | HTTP/Samba | docs/estado.md + smb-tests |
| `client1` | 172.16.0.21 | app Flask | `docker/app/`, `docs/app-db-runbook.md` |
| `admin-vm` | 192.168.20.140 (DHCP estática) | origen de tests | evidencias ops |
| `wan-vpn` | 10.20.30.60, wg 10.50.0.2 | peer WireGuard | keys nuevas (no versionadas) |
| `mon1` | 172.16.0.30 | PostgreSQL/Prometheus/Grafana | `docker/app/requirements.txt`, `config/ids/mirror.yaml` |

En cada guest:
1. Boot Alpine desde imagen base (slirp para paquetes): el flujo documentado está en `docs/estado.md` (boot con `-nic user` para `apk add`, luego apagar limpio).
2. Aplicar el archivo versionado correspondiente (fw.nft, dnsmasq, suricata mirror).
3. Regenerar secretos (no tomar del origen): `poc-root-password`, WireGuard keys, `inventory_app` password.

## 3) VPCS (estáticas / DHCP)

Los `startup.vpc` viajan en el export. Si falta alguno, la IP/gateway/DNS quedan en `config/lab.yaml` y `evidence/utp-lab-ids.json`.

## 4) Switches Dynamips

Las configs `.nvram` viajan en el export. Si se recrean, aplicar el mapping de puertos (access VLAN 10/20/40 vs dot1q trunk) documentado en `docs/estado.md`.

## 5) Verificación mínima post-bootstrap

- `GET /v2/projects/$PID/nodes` → 15 nodos; links ≥ 13; ninguno suspendido.
- Ping/VLAN: `pc-a10` → `192.168.10.1` 2–3/3.
- Consolas: mudas al primer boot TCG son normales.
- Reejecutar los checks de `docs/matriz-requisitos.csv` y comparar con `evidence/manifest.csv`.

## 6) No portable a propósito

- qcow2 con datos (PostgreSQL, Grafana, Samba share content).
- Secretos (wg keys, DB password, root password).
- PERF01 (omitido por decisión); MON01 PNG (no render bajo TCG).

Con estos pasos el destino queda funcional e idéntico excepto por las credenciales regeneradas, que es el comportamiento deseado.
