# Arquitectura destino — Entorno local Windows + WSL2 (Ubuntu) + Docker

**Fecha:** 2026-09-26 (UTC)  
**Alcance:** Migrar completamente el laboratorio fuera de GitHub Codespaces hacia una **PC local Windows con Ubuntu bajo WSL2**, donde corre Docker y un entorno Linux estable. Todo es local: sin SSH remoto, sin Codespaces.

## 1. Decisiones de topología de infraestructura

```
┌──────────────────────────── Windows PC ─────────────────────────────┐
│                                                                     │
│  GNS3 GUI 2.2.55  ──►  127.0.0.1:3080 (WSL2 NAT/localhost)          │
│                                                                     │
│  ┌──────────────────────── WSL2 Ubuntu ──────────────────────────┐  │
│  │                                                               │  │
│  │  Docker Engine                                                │  │
│  │  ├─ containers de servicio (web/app/db/dns/dhcp/samba/ids)    │  │
│  │  ├─ containers SDN (OVS SW1, OVS SW2, Ryu controller)         │  │
│  │  └─ contenedores cliente (Alpine livianos)                    │  │
│  │                                                               │  │
│  │  GNS3 Server 2.2.55 (orquesta topología, consolas)            │  │
│  │  └─ linked to Docker daemon (socket unix:///var/run/docker.sock)│  │
│  │                                                               │  │
│  │  Persistencia: volumen dedicado (p. ej. /var/lib/gns3-lab)    │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘

No hay SSH hacia otra PC ni Codespaces: el acceso del cliente GUI es loopback Windows↔WSL2.
```

**Nota de diseño honesta:** dentro de WSL2, GNS3 guiada en Windows y gns3server dentro de Ubuntu deben usar **la misma versión 2.2.55** (§11 del prompt ya documentó la incompatibilidad 2.2.61↔2.2.55). Linux nativo en WSL2 tiene CAP_NET_ADMIN/CAP_SYS_ADMIN dentro de su propio espacio, pero el bridge a la red Windows se trata como enlace externo de laboratorio (VLAN WAN), no como producción.

## 2. Controladores y componentes de gestión completos (todos los que pide el prompt)

| Capa | Componente | Rol | Ubicación (contenedor/VM) | Recursos pedidos en spec §4 |
|---|---|---|---|---|
| Switching SDN | **2× Open vSwitch** (OVS-SW1, OVS-SW2) | plato de datos OpenFlow 1.3, trunks dot1q | 2 contenedores Docker | 256–512 MiB c/u |
| **Controlador SDN** | **Ryu** (alternativas justificadas: ODL/ONOS requieren JVM ~2-4GB, fuera de presupuesto) | política central, reglas/cookies, demo SDN02 (bloqueo/restauración Ventas→HTTPS intranet) | 1 contenedor | 512–1024 MiB |
| Firewall/VPN | Linux + nftables + **OpenVPN TCP/1194** | routing inter-VLAN, ACLs, NAT hacia WAN, túnel VPN | 1 contenedor | 512 MiB |
| **DHCP** | **Kea DHCPv4** (alternativa: dnsmasq) | VLANs 10/20/40, relay por firewall | 2 contenedores (o 1) | 128–256 MiB c/u |
| **DNS** | **BIND9**, zona `empresa.test`, zonas inversas | recursión restringida, UDP/TCP 53 | integrado o dedicado | — |
| Web | **Nginx** intranet inventario | HTTPS 443 frontend | 1 contenedor | 256–512 MiB |
| Aplicación | Flask + Gunicorn (actual `docker/app/`) | API inventario | 1 contenedor | — |
| **Base de datos** | **PostgreSQL** dedicada | persistencia inventario | 1 contenedor VLAN30 | 512–1024 MiB |
| Archivos | **Samba** (shares administracion/ventas/comun) | SMBv2/v3, denegar SMB1 | 1 contenedor | 256–512 MiB |
| IDS | **Suricata** con **OVS mirror port** real | EVE alerta con SID propio | 1 contenedor | 512–1024 MiB |
| Monitoreo | **Prometheus + Alertmanager + Grafana** | series 15–30s, retención 3–7d, renderer PNG nativo disponible aquí | 1–3 contenedores | 1024–1536 MiB total |
| Clientes | Alpine/VPCS livianos | pruebas por VLAN | 3–4 contenedores | 64–128 MiB c/u |
| Almacenamiento | volúmenes Docker + backups pg_dump + config versionada | persistencia | host local | ≥8 GB libres |

**Suma de memoria objetivo (spec §4):** hasta **9–10 GiB** para el set, conservando ≥3 GiB para el host WSL2. En este entorno local es factible (Codespaces solo tenía 4 CPU y ~15 GiB compartidos con la plataforma).

## 3. Conexionado según spec (§5 del prompt) — nada omitido

| Conexión | Implementación en el entorno destino |
|---|---|
| SW1 ↔ SW2 | trunk 802.1Q con VLANs 10/20/30/40/99 |
| SW1 ↔ firewall | trunk etiquetado → subinterfaces gateway |
| Puertos access | uno por departamento; ambos switches se usan (prueba real) |
| Servidores | VLAN30 (DHCP .10, DNS .11, web .20, app .21, DB .30, archivos .40) |
| Monitoreo | VLAN99 |
| **Red de control OOB** | `172.29.250.0/24`: controlador `.10`, OVS-SW1 `.11`, OVS-SW2 `.12`, colector `.20` — gestión pura, sin datos de usuario |
| Interfaces de gestión OVS | **no** dentro de bridges de datos |
| Controlador reachable sin reglas auto-instaladas | directo por red OOB |
| Sensor IDS | puerto espejo OVS, sin IP, sin transmisión |
| Cliente VPN | segmento WAN distinto al LAN, demuestra acceso remoto |
| Solapamientos | verificar contra `/24` de Windows host y WSL2 antes de asignar |

**Uso de recursos documentado (extraído del prompt §4, no inventado):** la tabla de la sección 2 de este documento es la asignación objetivo original; al concluir la implementación se publicarán **medidas reales con `docker stats`** junto a cada contenedor (no se presupone).

## 4. Acceso y versionado obligatorio

- GUI Windows GNS3 2.2.55 ↔ gns3server WSL2 2.2.55 (misma versión exacta).
- Sin SSH remoto; toda la consola vía puerto local `127.0.0.1`.
- El socket Docker solo se monta donde lo necesite GNS3 server (no en dashboards/apps).
- Repo clonado en Ubuntu WSL2 con git; rama de trabajo `feat/docker-host-full` para no pisar `main` (histórico Codespace).

## 5. Fases de implementación (idénticas al prompt §12)

1. **diagnóstico host**: script `scripts/preflight-host.sh` (a crear) → GO sin condiciones esperado aquí.
2. **entorno**: Docker + GNS3 + imagen de prueba.
3. **red**: 2 OVS, trunk, VLAN, gateways, OOB.
4. **servicios**: Kea, BIND9, intranet HTTPS+DB, Samba.
5. **sdn**: Ryu, políticas, prueba de bloqueo/restauración, pérdida/recuperación del controlador.
6. **seguridad**: matriz firewall, OpenVPN, Suricata mirror real.
7. **monitoreo**: dashboards + PNGs + alertas probadas.
8. **pruebas**: suite integral, restauración, estabilidad (PERF01 30 min real).
9. **informe**: rellenar los 14 capítulos con resultados medidos.

## 6. Qué está excluido hasta nueva orden

- No se toca el Codespace `cuddly-bassoon-…` (queda como referencia histórica).
- No se borran las carpetas legacy del repo (`controller/`, `monitoring/`, `docker/`): pasan a ser el punto de partida del trabajo en la rama.
- Solo se versiona en git lo del host nuevo; el estado de Codespaces permanece congelado.
