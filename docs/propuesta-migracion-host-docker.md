# Propuesta de arquitectura: migración del lab a entorno local con Docker

**Fecha:** 2026-09-26 (UTC)  
**Alcance:** migrar la arquitectura funcional del Codespace a un **host local Linux con Docker**, y desde allí completar el 100% de la propuesta original (Docker nodos, OVS + Ryu SDN, VLANs del spec, OpenVPN, alertas con Alertmanager, etc.).  
**Restricción:** el laboratorio actual en Codespaces `cuddly-bassoon-…` queda intacto (solo referencia histórica y origen de evidencias); no se le aplican parches. El trabajo nuevo vive en el repositorio clonado en el host local.

## 1. Estado actual (origen) — verificado

| Elemento | Estado actual en Codespaces | Reutilizable vía repo |
|---|---|---|
| GNS3 2.2.55 API, daemon con auth desactivada | Implementado | `.devcontainer/gns3_server.conf`, skills de ops |
| Switches (Dynamips EtherSwitch) + trunk 802.1Q | Implementado (6 VLANs tags en captura) | `config/lab.yaml`, evidencias NET02/NET03 |
| Router-on-a-stick `fw1` (Alpine, DHCP/DNS/nftables/WireGuard/Suricata) | Implementado | `config/firewall/fw.nft`, `config/dns/lab.conf`, `config/ids/mirror.yaml`, scripts guest |
| VPCS clientes | Implementado | `startup.vpc` en `evidence`/`config` (por árbol de proyecto) |
| App inventario Flask + PostgreSQL 16 en mon1 | Implementado (APP01/DB01 PASS) | `docker/app/`, `docs/app-db-runbook.md`, evidencias |
| Samba, monitoreo Prometheus/Grafana, WireGuard | Implementado | evidencias SMB01/MON02/VPN01 |
| Topología GNS3 importable | `utp-network-lab.gns3` exportable | `scripts/export-lab.sh` → bundle portable |
| Compilación/images base | Alpine ISO + qcow2 | `scripts/bootstrap-images.sh` |

## 2. Limitaciones que bloquean el spec original en Codespaces (ya probadas)

| Blocking | Causa medida |
|---|---|
| Docker nodos | sin CAP_SYS_ADMIN/NET_ADMIN ni mounts (`dockerd` falla; verificado hoy) |
| Open vSwitch / OpenFlow | sin datapath; OVS userspace necesita TUN |
| `/dev/kvm`, `/dev/net/tun` ausentes | sandbox de la plataforma |
| Seccomp bloquea `unshare` | rootless Docker imposible |

Todo documentado en `docs/preflight.md`, `docs/estado.md`, matriz (ENV02, SDN01‑03 `NOT_FEASIBLE_IN_PLATFORM`).

## 3. Entorno destino propuesto

- Host Linux nativo o VM con KVM habilitado; container y kernel normales (sin sandbox Codespaces).
- Requisitos: Docker Engine ≥ 24, GNS3 Server **2.2.55 exacto** (mismo que la GUI en Windows), ≥16 GB RAM libre, ≥40 GB disco, sysctl `vm.max_map_count` si hiciera falta, OVS packages (kernel datapath).
- Acceso: API GNS3 en el host y SSH/túnel como se prefiera.

## 4. Arquitectura destino (100% prompt original)

| Capa | Implementación objetivo | Proviene de |
|---|---|---|
| Contenedores por rol | `docker/` existente + nuevos Dockerfiles para dhcp/dns/samba/web/db/ids/monitor | repo |
| Switching SDN | 2× OVS containers + OpenFlow 1.3 | hardware ya no limitado |
| Controlador | Ryu (`controller/`) o justificación a ODL/ONOS | `controller/` |
| Firewall/VPN | Linux container con nft + OpenVPN TCP/1194 (`172.29.250.0/24` OOB, `10.250.0.0/24` túnel) | scripts + `config/` nuevos en rama |
| VLANs según spec | 10.10.10/20/30/40/99 + DMZ, trunk 802.1Q entre switches | `config/lab.yaml` nuevo (no pisar el del Codespace) |
| Servicios | Kea DHCP, BIND9 (`empresa.test`), Nginx+App Flask HTTPS, PostgreSQL dedicado en VLAN30, Samba shares por departamento | `docker/{dhcp,dns,web,app,db,samba}` |
| IDS | Suricata en OVS mirror real (no tc en router) | `config/ids/` nuevo |
| Monitoreo | Prometheus + Alertmanager + Grafana; métricas SDN | `monitoring/` activado |
| Clientes | Containers Alpine/VPCS ligeros por VLAN | repo actual (VPCS) o Alpine en Docker |
| Evidencia | Matriz `docs/matriz-requisitos.csv` + `evidence/` con hashes | mismo formato.

## 5. Flujo de migración por clonación del repo

1. **PC/local**: clonar `lflores19/gns3-codespace-ssh` (o el fork) en el host destino.
2. Crear rama dedicada (sugerido): `feat/docker-host-full` para no ensuciar `main` (que sigue reflejando el estado Codespaces).
3. `scripts/preflight.sh` → en host debe reportar Docker/OVS/KVM OK; si no, parar antes de escribir código nuevo.
4. `docs/deploy-en-otra-cuenta.md` como base conceptual; reemplazar “Codespace” por “host local”.
5. Desplegar entorno dev no Codespace: hay que adaptar `.devcontainer` a no aplicar; el host corre daemon nativo (`gns3server --config ...`).
6. Reutilizar scripts: `export-lab.sh` (si se quiere traer el proyecto del Codespace) / import; `bootstrap-images.sh` para Alpine base; luego provisioning de nodos Docker desde `docker/`.
7. Ejecutar fases 2‑8 del prompt original: red (OVS + trunk), servicios, sdn, seguridad, monitoreo, pruebas.

## 6. Criterios de aceptación (sin desvíos)

- Aplicar los **22 requisitos ENV01‑PERF01** del prompt **contra el entorno local**, todos con evidencia en `evidence/` y estados PASS/NOT_RUN en la matriz.
- Lograr ENV02 (Docker), SDN01‑03 (controlador+OVS real), y PERF01 (30 min medidos), MON01 (captura PNG), VPN02 (cliente Windows real).
- Mantener el resultado de Codespaces documentado como “fase 1” (histórica); la nueva entrega es “fase 2 = completa”.

## 7. Riesgos a mitigar

- **Dos mundos simultaneos**: no mezclar en `config/lab.yaml` los direccionamientos; hacer un `lab.local.yaml` o rama propia.
- **Compatibilidad de versiones**: GNS3 GUI (Windows) y server host deben ser 2.2.55.
- **Datos sensibles**: credenciales nuevas en el host local; nunca subir los secretos nuevos a git.
- **Disco/RAM**: host debe tener realmente lo reservado; medir antes de decir que hay capacidad.

## 8. Próximo paso sugerido

Confirmame las specs del host destino (RAM/CPU, si tiene Docker, si es WSL2/VM/bare-metal). Con eso te:
1. Creo la rama `feat/docker-host-full`,
2. Dejo un `config/lab-host.yaml` con la arquitectura del prompt original,
3. Genero `scripts/preflight-host.sh` y el plan de ejecución fase a fase.

Listo para empezar cuando digas.