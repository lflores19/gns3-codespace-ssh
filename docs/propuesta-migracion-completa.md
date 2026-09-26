# Propuesta de migración — Codespace lab + capa Docker local

**Fecha:** 2026-09-26 (UTC) **Rama:** `feat/docker-host-full`  
**Alcance:** clonar el repo en tu PC local (Windows + WSL2 Ubuntu con Docker) y completar el 100% del prompt original en dos planos paralelos:

- **Plano A — Lab existente del Codespace** (QEMU/Dynamips/VPCS, 15 nodos, VLANs `192.168.x`, servicios Samba/WireGuard/Suricata/monitoreo). Se migra **tal cual**, sin reconstruir ni parchear archivos.
- **Plano B — Capa Docker local** (no disponible en Codespaces) para lo que el spec original exige pero el sandbox no dejaba correr: ENV02 (imágenes), SDN01‑03 (OVS + Ryu real), OpenVPN, Kea/BIND9, Nginx/alertmanager, etc.

## 1. Estado inicial verificado (origen = Codespace `cuddly-bassoon-…`)

| Ya implementado en Codespace | Migración |
|---|---|
| GNS3 2.2.55 API + 15 nodos + 13 enlaces (`utp-network-lab`) | `scripts/export-lab.sh` → bundle portable |
| Switches EthernetShift + trunks 802.1Q | migrados como nodos del bundle (ISO/Dynamips) |
| Router-on-a-stick fw1 + dhcp/dns/nftables/WireGuard/Suricata | Ataes via binary backups qcow2 (no en git) |
| VPCS clientes | incluidos en el bundle (`startup.vpc` exportados) |
| App inventario + PostgreSQL | migrada vía repo + `scripts/bootstrap-images.sh` |
| Monitoreo Prometheus/Grafana, Samba, WireGuard | Ataes via qcow2 backups |

**Los qcow2 y binario no entran en git** (filtro en `.gitignore`); acceso por copia separada o resbootstrap.

## 2. Entorno destino (Windows + WSL2 Ubuntu + Docker)

```
Windows PC
│
├─ GNS3 GUI 2.2.55 (Windows)  ──► 127.0.0.1:3080 (loopback WSL2)
│
└─ WSL2 Ubuntu
    ├─ gns3server 2.2.55 (usa el proyecto migrado del Codespace)
    ├─ Docker Engine ≥ 24
    │   ├─ Plano B: containers nuevos (OVS×2, Ryu, Kea, BIND9, OpenVPN,
    │   │             Nginx+app, PostgreSQL, Samba, Suricata, Alertmanager)
    │   └─ Nodos extras Docker si hace falta
    └─ Disco persistente volumen dedicado (≥40 G libres)
```

Las decisiones (versión GNS3 fija 2.2.55, sin SSH remoto, recursos según spec §4) están en `docs/arquitectura-destino.md`.

## 3. Flujo de migración vía clonación de repo

**Tus próximos pasos en tu PC (sin que yo haga nada en el Codespace):**

```bash
# 1) clonar repo y entrar a la rama de migración
git clone https://github.com/lflores19/gns3-codespace-ssh.git
cd gns3-codespace-ssh
git checkout feat/docker-host-full

# 2) validar host local (GO/NO-GO explícito)
bash scripts/preflight-host.sh

# 3) traer el bundle ya exportado del Codespace, o volver a exportar ahí y copiar
bash scripts/export-lab.sh   # (ejecutar en Codespace si el bundle no está listo)
# copiar gns3-lab-export/ + .gns3_private_backups (qcow2) a tu PC

# 4) reconstituir el proyecto en tu PC
bash scripts/import-lab.sh /ruta/al/bundle/
bash scripts/bootstrap-images.sh

# 5) levantar gns3server (Windows GNS3 GUI conectado a el)

# 6) arrancar la capa Docker complementaria (etapas 2‑5 adicionales)
docker compose -f deploy/host/docker-compose.sdn.yml up -d --build
```

## 4. Cómo se conectan ambos planos

- **IP plan**: se mantiene el siguiente del lab Codespace (`192.168.x`, `172.16.0.x`, `10.20.30.x`) y no se cambia. La capa Docker usa segmentos **propios** (OOB `172.29.250.0/24` según spec §5, y/o VLANs nuevas si el spec lo pide) para no colisionar con VLANs vivas.
- **Interconnect**: los switches Docker (OVS) se conectan con los switches OVS/Dynamips de GNS3 por una red interna — el enfoque concreto (vxlan entre redes Docker y GNS3, u udp tunnels, o gns3 node Docker nativo) se define en la fase cuando ya recorramos la migración y midamos el comportamiento con OVS y docker networks real.
- **Firewall**: los rangos nuevos de la capa Docker se suman a la matriz nftables ya existente en fw1 (config versionada `config/firewall/fw.nft`).

## 5. Etapas ya realizadas en esta rama (como soporte a la migración)

| Etapa | Estado en rama |
|---|---|
| 0‑2: preflight, devcontainer propio, build-images | listas |
| 3: plano SDN base (OVS×2 + Ryu controller, healthchecks, OOB `172.29.250.0/24`) | listo para compilar |
| 4: VLANs 10/20/30/40/99 + trunk SW1↔SW2 tagged (tests de validación) | ready a ejecutar |
| 5: firewall router‑on‑a‑stick + gateways 10.10.*.1 + nftables básico | ready a ejecutar |

## 6. Verificación obligación antes de marcar PASS

- En tu PC: `bash scripts/preflight-host.sh` → GO sin FAILs.
- Migración: `bash scripts/import-lab.sh` con checksums OK, nodos arrancan, trunk capturable (NET02 re-validado).
- Capa Docker: `bash scripts/verify-stage4.sh` y `verify-stage5.sh` pasando en tu PC.
- Solo al cierre de ambas pruebas se marca como operativo el funcionamiento conjunto.

## 7. Riesgos principales

- **Versiones GNS3**: Windows GUI y gns3server en WSL2 deben ser 2.2.55; cualquier 2.2.61/2.2.xx ya está documentada como incompatible (`docs/informe.md` §11).
- **Versiones Openvswitch**: IMG nueva vs la que probaron MACON; preflight da la respuesta.
- **Recursos**: hay que tener ≥16 GiB RAM y ≥32 GiB disco libre; el spec original está calibrado hasta ~10 GiB de containers, y el lab QEMU existente pide ~8 GiB; margen honesto = no bajar del piso que marca WSL2.

Cuando confirmes que entendiste el encuadres, sigo con la siguiente etapa (documentar y preparar STAGE 6: matriz nftables completa del prompt).