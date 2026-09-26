# Despliegue exacto — host local Windows + WSL2 Ubuntu + Docker

**Rama:** `feat/docker-host-full` **Fecha:** 2026-09-26 (UTC)  
**Regla:** solo se documentan valores provenientes del prompt original (§4–§11) o de lo ya versionado; nada inventado. Lo no medido se marca **PENDIENTE DE MEDIDA** y se cierra con `scripts/preflight-host.sh` + `docker stats` en el host.

## 1. Inventario de arquitectura (piezas, versión, recursos)

| Rol | Componente | Recursos (spec §4, objetivo) | Notas de compilación |
|---|---|---|---|
| GNS3 server | `gns3-server` **2.2.55 exacto** (fijado en setup) | comparte host | igual que GUI Windows; no actualizar por separado |
| Switch SDN ×2 | Open vSwitch (OVS-SW1, OVS-SW2) | 256–512 MiB c/u | datapath kernel en host WSL2 |
| Controlador SDN | Ryu (`controller/`) con app `simple_switch_13.py`/políticas | 512–1024 MiB | OpenFlow 1.3, puerto 6653, fail-mode `secure` |
| Firewall / VPN | Alpine Linux + nftables + OpenVPN TCP/1194 | 512 MiB | túnel `10.250.0.0/24` |
| DHCP | Kea DHCPv4 | 128–256 MiB | VLAN10/20/40, relay en firewall, giaddr verificado |
| DNS | BIND9 | 128–256 MiB | zona `empresa.test` + inversas; UDP/TCP53 |
| Web | Nginx intranet | 256–512 MiB | HTTPS 443 front; HTTP 80 solo redirección |
| App | Flask/Gunicorn (repo `docker/app/`) | 256–512 MiB | usuario DB mínimo `inventory_app` |
| DB | PostgreSQL 16 | 512–1024 MiB | volumen dedicado, `pg_dump` job |
| Samba | shares administracion/ventas/comun | 256–512 MiB | SMB1 deshabilitado |
| IDS | Suricata + OVS mirror port | 512–1024 MiB | EVE con SID propio |
| Monitoreo | Prometheus + Grafana + Alertmanager | 1024–1536 MiB total | retención 3–7d |
| Clientes ×3–4 | Alpine liviano | 64–128 MiB c/u | pruebas por VLAN |

**Suma objetivo del set:** 9–10 GiB (spec §4). Reserva host: ≥3 GiB para WSL2. **Estos son objetivos del spec; la medida real se documentará con `docker stats` y `docker inspect` después del primer despliegue (PENDIENTE DE MEDIDA).**

## 2. Plan de direccionamiento y redes (spec §5, sin cambios)

| VLAN | Segmento | Subred | Gateway (en fw) | DHCP pool | Reservas |
|---|---|---|---|---|---|
| 10 | Adm | 10.10.10.0/24 | 10.10.10.1 | .100–.149 | cliente autorizado .10 |
| 20 | Ventas | 10.10.20.0/24 | 10.10.20.1 | .100–.149 | — |
| 30 | Servidores | 10.10.30.0/24 | 10.10.30.1 | Estáticos | dhcp .10, dns .11, web .20, app .21, db .30, archivos .40 |
| 40 | Invitados | 10.10.40.0/24 | 10.10.40.1 | .100–.149 | — |
| 99 | Gestión | 10.10.99.0/24 | 10.10.99.1 | Estáticos | monitoreo .20 |
| — | **OOB control** | **172.29.250.0/24** | — | Estáticos | ctrl .10, SW1 .11, SW2 .12, colector .20 |
| — | VPN túnel | 10.250.0.0/24 | gateway .1 | Estáticos | cliente .2 |

**Restricciones del spec §5**: el OOB solo lleva control (nunca datos de usuario); interfaces de gestión OVS no se unen a bridges de datos; hay que validar solapamientos con la red de Windows host/WSL2.

## 3. Matriz de conexiones (spec §5 · obligatoria)

| Link | Medio | Notas |
|---|---|---|
| SW1 ↔ SW2 | trunk 802.1Q con VLAN10/20/30/40/99 | prueba real atravesando ambos switches |
| SW1 ↔ Firewall | trunk etiquetado | subinterfaces del FW definen gateways |
| Departamentos | puertos access en SW1/SW2 | una VLAN por rol; ambos switches usados |
| Servidores | VLAN30 | trunk o access hacia OVS |
| Monitoreo | VLAN99 | tráfico de scraping/alertas |
| OOB | red bridge dedicada | controlador `172.29.250.10`; OVS `.11`/`.12` |
| Controller ↔ SW1/SW2 | OpenFlow 6653 sobre OOB | **no** por plano de datos |
| Sensor IDS | espejo OVS hacia puerto sin IP del IDS | visibilidad del enlace vigilado |
| Cliente VPN | segmento WAN separado (no LAN) | demuestra acceso remoto |

## 4. Secuencia de despliegue exacta (spec §12, con validación por etapa)

Cada etapa se da por cerrada solo cuando su check pasa:

| Paso | Acción | Check antes de seguir |
|---|---|---|
| 0 | `bash scripts/preflight-host.sh` | GO (sin FAIL; WARN aceptables) |
| 1 | `docker version` + `docker run --rm hello-world` | OK |
| 2 | `scripts/build-images.sh` (a crear) — compila todas las imágenes | `docker images` muestra tags fijados (no `:latest`) |
| 3 | levantar solo SDN: SW1+SW2+controller; `ovs-vsctl show` + `ovs-ofctl -O OpenFlow13 dump-flows` | datapaths up, OF 1.3, controller conectado |
| 4 | VLANs y trunk entre switches + firewall subinterfaces; pings por VLAN, aislamiento cross-VLAN | NET01..NET04 parciales PASS |
| 5 | servicios: Kea, BIND9, Nginx+app, PostgreSQL, Samba | DHCP renueva y mantiene VLAN (giaddr OK), DNS UDP+TCP53, app alta/lectura persistente, share permitido+denegado |
| 6 | VPN: OpenVPN con certificados, cliente WAN, reach solo a recursos permitidos | handshake + rutas solo permitidas |
| 7 | IDS: Suricata en mirror OVS; generar tráfico de prueba; EVE/alerta con SID | archivos EVE + PCAP correlacionados |
| 8 | Probar PÉRDIDA/RECUPERACIÓN del controlador | comportamiento documentado (modo secure) |
| 9 | Monitoreo: Prometheus targets, alertas disparar/resolver, Grafana PNG (renderer disponible aquí) | dashboard con hora + queries |
| 10 | PERF01: 30 min del set completo, consumo medido | tabla CPU/RAM/disco/latencia real |
| 11 | Rellenar `tests/acceptance.md` + `evidence/manifest.csv` + `docs/informe.md` completo | PASS/FAIL/BLOCKED por requisito |

## 5. Checklist anti-fallos (extraída del prompt §6 y §11)

- Fijar versiones y digests de imágenes tras probar (no `latest`).
- Scripts con `set -Eeuo pipefail`, validación de variables, rutas citadas, `trap` para limpieza.
- Healthchecks con timeout real (no sleeps arbitrarios).
- Capacidades por contenedor: mínimas necesarias (`cap-add` puntuales).
- No publicar Docker API sin autenticación; socket solo donde sea imprescindible.
- `.env.example` sin secretos; secretos fuera de git modo 0600.
- Backups versionados + restauración de un dato de prueba como condición.
- Consolas telnet/web locales por túnel; nada público.

## 6. Gaps que NO se cerrarán aquí (verdad al final)

- Sin SDN en produccion real; la etiqueta SDN aplica solo si el controlador Ryu gestiona políticas OpenFlow.
- Active Directory queda excluido (perfil Docker Linux sin Windows Server).
- HTTPS con cert solo "de laboratorio" (autofirmado); sino se indica, no se llama válido público.

Cuando confirmes que leíste esto, genero los scripts de la etapa 0–2 y el árbol `deploy/host/` en esta misma rama.
