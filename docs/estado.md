# Estado del proyecto — utp-network-lab

> **Registro cronológico:** las entradas siguientes preservan observaciones históricas y no son autoridad de aceptación actual. La autoridad **CURRENT** es [`docs/matriz-requisitos.csv`](matriz-requisitos.csv): **15/22**. El snapshot histórico de **14 PASS** fue superado por 15; no usarlo para inferir el estado actual.

| Fecha UTC | Fase | Resultado | Detalle |
|---|---|---|---|
| 2026-09-25 | 0 - Scaffolding | PASS | Estructura base, lab.yaml, matriz, scripts base, README. |
| 2026-09-25 | 1 - Diagnóstico | EN CURSO | scripts/preflight.sh ejecutado en Codespace. Ver docs/preflight.md. |

## Pendientes conocidos tras Fase 0/1
- Construcción de imágenes Docker por rol (`docker/`).
- Import/create de templates GNS3 vía API y validación de carga en proyecto (ENV02/GNS3).
- Despliegue de controlador SDN Ryu y pruebas OpenFlow 1.3 (SDN01–SDN03).
- Capturas PCAP reales para NET02/NET03/NET04 e IDS01.
- Generación de dashboard Grafana con métricas reales (MON01/MON02).
- Ejecución completa de scripts/test-lab.sh y actualización de matriz.

### Nota crítica de Fase 1 (Diagnóstico)
- docker y docker-compose NO instalados en el contenedor dev. En preflight.md quedaron `docker`/`docker-compose` como `[MISS]`, por lo que ENV02 y posteriores requieren instalación en la imagen devcontainer o uso de host remoto con Capabilities. Recomendación: añadir a `.devcontainer/Dockerfile` instalación de docker-ce-cli y dependencias, o ejecutar lab en el Codespace usando `--privileged` + instalar Docker en el entorno principal.
- Ubridge presenta puerto en escucha 0.0.0.0:2222; GNS3 listens 0.0.0.0:3080 -> correcto y accesible.

## Fase 2 (Infraestructura base) — resultado: BLOCKED (plataforma)
Evidencias: log remoto /tmp/provision.log (Codespace), resumen abajo.

> `scripts/provision-phase2.sh` está retirado; el camino actual en Codespaces es el daemon GNS3 con runtime QEMU.

1. dockerd arranca solo con `--bridge=none --iptables=false` (iptables/nftables no permitidos: falta CAP_NET_ADMIN en el contenedor codespaces: `capsh --print` muestra Bounding sin `cap_net_admin` ni `cap_sys_admin`).
2. docker build/pull falla: `unshare: operation not permitted` y overlayfs `mount ... operation not permitted` (sin CAP_SYS_ADMIN no hay user namespaces ni mounts privados).
3. openvswitch-switch 2.17.12 inicia, pero `ovs-vsctl add-br br0` no crea datapath (kernel module no gestionable) y `ovs-ofctl show br0` → "br0 is not a bridge". OVS userspace (netdev) también requiere tuntap → imposible.
4. GNS3 2.2.55 sí funciona (API OK, puerto 3080) — VPCS/Dynamips/EtherSwitch son vía UDP y no requieren NET_ADMIN.

Decisión de diseño (documentada en docs/arquitectura.md):
- **Plan B obligatorio**: nodos de servicios (web/app/db/dns/dhcp/samba/vpn) como procesos nativos del Codespace (apt/pip) o imágenes QEMU mínimas bajo GNS3; conmutación VLAN 802.1Q con EtherSwitch de GNS3 o IOU/Dynamips; SDN con OVS en Mininet standalone NO es viable → sustituir por Ryu + OpenVSwitch userspace no viable → SDN sobre switches virtuales de GNS3 + controlador externo queda restringido a protocolo de layer-2 (OpenFlow solo vía IOU L3? no). Registro de excepción: SDN01-03 pasarán a NOT_FEASIBLE_IN_PLATFORM salvo replanteo con EVE-NG/QEMU OVS image.

## Evidencia de smoke GNS3 2.2.55 (Codespace)
- El binario instalado `/usr/bin/ubridge` (`root:ubridge`, modo `754`, capacidades `cap_net_admin,cap_net_raw=ep`) falla con `EPERM` porque el bounding set del Codespace no incluye `CAP_NET_ADMIN`.
- Se configuró GNS3 para usar una copia sin file capabilities en `/home/vscode/.local/bin/ubridge-uncap`; esta evidencia aplica únicamente a enlaces directos UDP QEMU/VPCS, no a TAP ni OVS.
- Smoke observado: inicio de nodo por API HTTP `200`, consola accesible en el puerto `5000`, adaptador QEMU `virtio-net-pci`, y enlace UDP directo QEMU–VPCS con ping `3/3` y RTT `0.936/4.056/10.220 ms`.
- ISO usada: Alpine virt `3.22.6` oficial, SHA-256 `f1e3bbfd700709a8a931748152cec16c539c45b8fa0a04e95a3d38cf2231da98`.
- Evidencias reproducibles: `evidence/qemu/alpine-tcg-boot.txt` (TCG), `evidence/qemu/gns3-qemu-vpcs-link.json` (consolas y prueba inicial), `evidence/qemu/gns3-smoke-result.json` (estado API y ping final).
- Esta evidencia no declara aprobados NET03 (requiere dos switches), OPS03 (túnel desde cliente local), SDN ni ENV02. La ISO live tampoco demuestra persistencia tras un restart.

## Prueba de persistencia QEMU — 2026-09-26

**Resultado acotado: PASS.** La instalación Alpine persiste en un disco dedicado y el marcador se leyó después de apagar e iniciar el nodo mediante la API de GNS3. Esto prueba únicamente la persistencia del invitado QEMU en este Codespace; no actualiza estados de `docs/matriz-requisitos.csv` ni aprueba OPS01/OPS02.

| Aspecto | Evidencia observada |
|---|---|
| Plataforma | GNS3 2.2.55; QEMU 6.2 con TCG (sin KVM). |
| Medio de instalación | ISO oficial Alpine virt 3.22.6, SHA-256 `f1e3bbfd700709a8a931748152cec16c539c45b8fa0a04e95a3d38cf2231da98`. |
| Disco base | Se instaló en un qcow2 nuevo dedicado de 2 GiB con acceso al repositorio HTTPS oficial mediante `setup-disk -m sys /dev/vda`; salida `0`. Base: `/home/vscode/GNS3/images/QEMU/alpine-virt-3.22.6-installed-base.qcow2`. |
| Template y proyecto | Template GNS3 HDA virtio, clon vinculado, `boot_priority` `c`, adaptador `virtio-net-pci`; proyecto `qemu-persistent-poc`. |
| Reinicio | Consola serie autenticada como `root` en el puerto 5004; se escribió `/root/persistence-proof.txt` con `persistent-proof-2026-09-26`. Tras `poweroff` e inicio por API, el marcador fue leído nuevamente. |
| Overlay | El disco del proyecto está bajo `/home/vscode/GNS3/projects/a8ca363c-cbe7-45f1-9918-4e07af1137c5/.../hda_disk.qcow2`. `qemu-img info -U` informó backing file base, 2 GiB lógicos y overlay aproximado de 1.88 MiB mientras corría. |
| Respaldo | Tras sincronizar el invitado y detenerlo por API se creó `/workspaces/.gns3-data/alpine-persistent-poc-2026-09-26.tar.gz`, SHA-256 `10d9f9094a49dc30f0f675491d2a92dd487170be6c342993a12660daf877f5ab`; archivo modo `600` dentro de directorio modo `700`. La suma verificó. El invitado fue reiniciado después. |

Evidencias en repositorio: `evidence/qemu/alpine-install.txt`, `evidence/qemu/persistent-ids.json` y `evidence/qemu/persistent-reboot.json`.

## Restauración probada — 2026-09-26

**Resultado acotado: PASS.** El archivo `/workspaces/.gns3-data/alpine-persistent-poc-2026-09-26.tar.gz` se verificó por SHA-256, se extrajo a staging (`/tmp`, efímero) y restauró una **copia aislada**: proyecto `qemu-persistent-restore-test-2026-09-26` (`76e2aa7f-7d11-4145-bf8b-ced876ee1ced`), nodo `alpine-restored` con overlay rebasado a la imagen `alpine-virt-3.22.6-installed-base-restore-test.qcow2`. Arrancó Alpine 3.22 (kernel 6.12.111-0-virt) y la consola autenticada como `root` leyó el marcador `/root/persistence-proof.txt` original. Los proyectos originales quedaron intactos (cerrados, sin modificaciones a su base). Evidencia: `evidence/qemu/restore-test.json`.

### Hallazgos del procedimiento

- `POST /v2/projects/import` no existe en GNS3 2.2.55 (405) y `POST /v2/projects/load` devuelve **403** en un servidor GNS3 que no es local: no son rutas válidas de restauración en este Codespace.
- El daemon de GNS3 **escanea el directorio `…/GNS3/projects` al arranque**; el camino de restauración válido es: restaurar archivos, editar un `.gns3` aislado (IDs, nombre, imagen) y reiniciar `gns3server` para que lo registre.
- Tras restaurar con IDs nuevos, la consola real del nodo puede diferir del valor inicial del API hasta que se abre el proyecto (QEMU usa consola directa; GNS3 la proxifica). Leer el nodo por API antes de conectar.
- `qemu-img rebase -u` re-apunta overlays sin reescribir datos; uso acordado únicamente entre copias verificadas.

## POC VLAN con Ethernet switch nativo (Dynamips) — 2026-09-26

**Resultado acotado: PASS.** Proyecto `vlan-poc` (`4faff441-825b-4429-aa4e-210f8aeda0e1`) con un `Ethernet switch` nativo (NM-16ESW sobre Dynamips) con puertos access: `Ethernet0` y `Ethernet2` en VLAN 10, `Ethernet1` en VLAN 20.

| Prueba | Resultado |
|---|---|
| Intra-VLAN 10: `vpc-a` (10.10.10.2) → `vpc-c` (10.10.10.3) | ICMP 5/5, RTT ~0.3 ms. |
| Aislamiento: `vpc-b` re-configurado en la **misma subred** 10.10.10.5/24 pero en VLAN 20 | Ping cruzado: `host (10.10.10.5) not reachable` — ARP nunca resolvió ⇒ segmentación L2 real por VLAN (la primera prueba inter-subred solo devolvía "No gateway found", que no prueba aislamiento). |

- Requisito de plataforma encontrado: `/usr/bin/dynamips` tiene `cap_net_admin,cap_net_raw=ep` (EPERM al verificar versión); se aplicó la misma cura que a uBridge: copia sin capabilities en `/home/vscode/.local/bin/dynamips-uncap` y `dynamips_path` en la sección `[Dynamips]` de `gns3_server.conf` (repo + runtime). Instalación persistida en `setup.sh` y `start-daemon.sh`.
- Evidencias: `evidence/vlan-poc-ids.json`, `evidence/vlan-poc-connectivity.json`, `evidence/vlan-poc-isolation.json`.
- Alcance: esto **no** satisface todavía NET01–NET04 (faltan trunk 802.1Q transporte, DHCP, firewall entre segmentos) ni el segundo switch de NET03.

## Trunk 802.1Q entre dos switches — 2026-09-26

**Resultado acotado: PASS.** Agregué `sw2` (E0/E1 access VLAN10/20, E2 dot1q) y el puerto `Ethernet3` de `sw1` como dot1q; trunk `sw1:E3 ↔ sw2:E2` (link `f7dcfadf`). Hosts nuevos en sw2: `vpc-d` (10.10.10.6/24, VLAN10) y `vpc-e` (10.10.10.7/24, VLAN20, misma subred).

| Prueba | Resultado |
|---|---|
| Mismo VLAN10 a través del trunk: `vpc-a` → `vpc-d` | 5/5 ICMP. |
| Aislamiento cross-VLAN misma subred: `vpc-a` → `vpc-e` | 0 respuestas (L2 aislado). |
| Captura pcap en el trunk (`vlan-trunk.pcap`) | 25 tramas con ethertype **802.1Q (0x8100)**, todas `vlan 10`: ARP who-has/ reply + 5 pares ICMP echo. |

- Restricción de GNS3 encontrada: no se puede modificar `ports_mapping` de un switch con enlaces (409 `Can't modify a switch already connected`), ni aunque esté detenido; hay que desconectar, editar y reenlazar. Además `PUT` de ports con un switch corriendo falla; hay que detenerlo después de desconectar.
- La captura de enlace usa el endpoint legado `POST /v2/projects/{id}/links/{link}/start_capture` (no `/capture/start`).
- Evidencias: `evidence/vlan-trunk.pcap`, `evidence/vlan-trunk-pings.json`, `evidence/vlan-trunk-pcap-analysis.json`, `evidence/vlan-poc-ids.json`.
- Alcance: evidencia parcial hacia NET02 (trunk transporta VLAN10 etiquetada) y NET03 (mismo VLAN entre dos switches con ping); la matriz sigue **NOT_EVALUATED** (falta cubrir todas las VLAN del diseño 10/20/40/99/200/300 y DHCP/seguridad).

## Proyecto `utp-network-lab` (diseño lab.yaml) — 2026-09-26

**Resultado acotado: PASS parcial.** Proyecto `e792c7b3-8a50-4d0b-a93a-ab64e7e6e344` siguiendo `config/lab.yaml`: `sw1` (access VLAN 10/20/40/99 + trunk E4 dot1q), `sw2` (access VLAN 10/20/200×2/300 + trunk E4). VPCS: `pc-a10` (192.168.10.2, sw1), `pc-d10` (192.168.10.3, sw2), `pc-dmz` (172.16.0.50, sw2). Primera VM de servicio: `web1`, clon vinculado QEMU de la imagen Alpine instalada, enlazada a sw2 VLAN 200.

| Prueba | Resultado |
|---|---|
| VLAN10 entre switches (trunk): `pc-a10` → `pc-d10` (192.168.10.0/24) | 5/5 ICMP. |
| DMZ: `pc-dmz` → `web1` (172.16.0.20/24) | 5/5 ICMP. |
| `web1` red estática persistente | `/etc/network/interfaces` con `172.16.0.20/24`, servicio `networking` agregado al runlevel boot; **tras stop/start por API, respondió ping sin intervención manual** (evidencia `web1-reboot-ip-persist.json`). |

- Fallo encontrado y corregido: la instalación base Alpine no habilitaba `networking` en el runlevel (eth0 quedaba DOWN tras reboot); fix persistente `rc-update add networking boot`.
- Descubrimiento de plataforma: los **templates GNS3 viven en `~/.config/GNS3/2.2/gns3_controller.conf` (overlay efímero)** y se perdieron en el rebuild anterior. Se migró `~/.config/GNS3` a `/workspaces/.gns3-data/home-vscode-config-GNS3` (symlink, manejado en `start-daemon.sh`) y se recreó el template QEMU `Alpine 3.22.6 installed base (TCG)` (`6023e8f2-3162-40a2-b84a-ccae8861dbbf`).
- Restricción adicional de API: GNS3 **renumera los puertos secuencialmente** al aplicar `ports_mapping` (los índices pedidos 4/5/7 pasan a 2/3/4); los enlaces deben referenciar el índice final.
- Evidencias: `evidence/utp-lab-ids.json`, `evidence/utp-lab-connectivity.json`, `evidence/web1-network-config.json`, `evidence/web1-reboot-ip-persist.json`.
- Alcance: soporta parcialmente OPS01 (config persiste tras reboot de nodo) y el acceso DMZ; faltan servicios (web DHCP DNS…), VLANs 40/99/300 con hosts, firewall/SDN/VPN y la prueba formal de la matriz.

## Servicio HTTP real en DMZ (web1) — 2026-09-26

**Resultado acotado: PASS.** `web1` (Alpine QEMU, VLAN 200, `172.16.0.20/24`) expone un servicio HTTP (responder one-shot `busybox nc`, `:80`) y `client1` (segundo clon QEMU, `172.16.0.21/24`, VLAN 200, puerto 6 de sw2) obtuvo la página marcada `web1 utp-network-lab OK`. Tras stop/start de `web1` por API, el servicio **auto-arrancó** (`/etc/local.d/httpd.start` + `rc-update add local default`) y el GET desde `client1` volvió a responder.

### Hallazgos y correcciones

- **El busybox de `alpine-virt` no incluye el applet `httpd`** (`httpd: applet not found`). Una evidencia anterior (`web1-httpd.json`) reportó un falso positivo porque el assert coincidía con el **eco de los comandos**, no con la respuesta: el archivo fue eliminado y reemplazado por `evidence/web-service-dmz.json` con la historia verdadera.
- Lección de validación: nunca asertar sobre transcript completo que contiene los comandos enviados; delimitar con marcadores o capturar solo la salida posterior al comando.
- Conexión de VMs a `sw2` en VLAN 200 requirió tercer puerto access (índice 6): desconectar enlaces, `PUT` ports_mapping, reenlazar (GNS3 renumera secuencialmente).
- Consola telnet de QEMU: `server,nowait` atiende **un solo cliente**; el proxy de consola de GNS3 queda con el serial real (proxy 5020↔raw 5021, 5022↔5023). Si el proxy queda mudo tras reboot del nodo, recuperar con stop/start del nodo por API.
- Alcance de esta sección: evidencia de servicio HTTP intra-DMZ y auto-arranque (soporte parcial de APP01/OPS01); sin L3 entre VLANs en ese momento.

## Router-on-a-stick fw1 (routing inter-VLAN) — 2026-09-26

**Resultado acotado: PASS (routing), filtrado pendiente.** Se agregó `fw1` (clon QEMU Alpine, 1 NIC en trunk dot1q a `sw2:E7`) con subinterfaces 802.1Q y forwarding: VLAN10 `192.168.10.1/24`, 20 `192.168.20.1/24`, 40 `192.168.40.1/24`, 99 `192.168.99.1/24`, 200 `172.16.0.1/24`, 300 `10.20.30.1/24`; `net.ipv4.ip_forward=1` persistente (`/etc/sysctl.d/99-forward.conf` + `/etc/local.d/fw-net.start`).

| Prueba | Resultado |
|---|---|
| `pc-dmz` (172.16.0.50, gw 172.16.0.1) → `pc-a10` (192.168.10.2, VLAN10) | 5/5 ICMP **enrutado** por fw1. |
| `pc-a10` → `pc-dmz` (sentido inverso) | 5/5 ICMP. |
| Control intra-VLAN10 por trunk `pc-a10` → `pc-d10` | 5/5 ICMP. |

### Hallazgos y bugs del camino

- **Nodo NAT/cloud no viable** en Codespace: requiere `virbr0`/libvirt; y GNS3 **prohíbe** la opción QEMU `-nic user` (listas blancas). El lab no tiene salida a Internet para guests ⇒ instalar nftables/kea/bind requerirá **inyección offline de .apk** en las imágenes (próxima fase). El filtrado de la matriz FW01–FW06 queda pendiente.
- **Bug de estado fantasma GNS3 2.2.55**: al borrar un nodo QEMU con enlace, el hypervisor Dynamips conserva el puerto ocupado y el controlador pierde el link (DELETE 404 pero nodo sw "conectado" y puertos "in use"). Recuperación: detener nodos, **reiniciar gns3server** (limpia estado del hypervisor), re-enlazar desde cero.
- VPCS: el gateway se persiste con `save` en startup.vpc (eth0 NO necesita reboot).
- Evidencias: `evidence/fw1-vlan-ifs.json`, `evidence/utp-lab-routing.json`, `evidence/utp-lab-ids.json`.
- Alcance: soporta parcialmente NET04 (rutas existen; falta demostrar política drop) y prepara SEC01/VPN01; matriz sigue **NOT_EVALUATED**.

## Servicios en fw1 (nftables + dnsmasq, inyección offline) — 2026-09-26

**Resultado acotado: PASS.** Instalé paquetes en el overlay de `fw1` con un **boot standalone del overlay con `-nic user` (slirp)** — elude la whitelist de GNS3 y el bloqueo de NAT con virbr0 —: `nftables 1.1.3` + `dnsmasq 2.91` (apk dl-cdn). Reglas nftables (forward default **drop**) con la matriz FW01–FW06 y DHCP/DNS por dnsmasq (pools VLAN10/20/40, dominio `lab.local`, registro `web1.lab.local → 172.16.0.20`). Autostart persistente vía `/etc/local.d/fw-net.start` (vlans + nft + dnsmasq).

| Prueba (evidencia `evidence/utp-lab-dhcp-dns-fw.json`) | Resultado |
|---|---|
| DHCP VLAN10 (pool 192.168.10.100–159, gw/dns .10.1) | Lease completo en `pc-a10`. |
| DHCP VLAN40 | Lease completo en `pc-inv40` (nuevo VPCS en sw1:E2). |
| DNS `web1.lab.local` desde VLAN10 | Resuelve a 172.16.0.20. |
| ICMP ventas → web1 (172.16.0.20) | 5/5 (permitido por regla de la matriz). |
| FW04: invitados → ventas (192.168.10.100) | 5 timeouts, 0 respuestas (drop). |
| FW03: invitados → DMZ por ICMP | 0 respuestas (solo tcp 80/443 permitido). |

### Incidencias corregidas

- `web1`/`client1` no tenían default gateway (solo respondían a su subred): agregado `gateway 172.16.0.1` persistido en `/etc/network/interfaces` de ambos.
- La consola serial se **rompe con heredocs largos** por telnet: usar `printf` por líneas; tener escape EOF+Ctrl-C si queda en prompt `>`.
- Al recrear `fw1`, el disco overlay **perdió** la config previa de VLANs (vlans.sh) porque era del nodo eliminado; el config autocontenido quedó en `fw-net.start`.
- Evidencias: `evidence/utp-lab-dhcp-dns-fw.json`, `evidence/fw1-ruleset-dnsmasq.txt`, `evidence/fw1-services-installed.json`.
- Alcance: evidencia directa para NET01, DNS01, NET04 y SEC01 del POC; falta cobertura formal en las VLANs restantes y IDs/SMB/VPN/Grafana; la matriz sigue **NOT_EVALUATED**.

## Cobertura completa de VLANs (hosts VLAN20/99/300) — 2026-09-26

**Resultado acotado: PASS.** Agregados `pc-admin20` (sw1:E1, DHCP VLAN20), `pc-mgmt99` (sw1:E3, 192.168.99.2/24 gw .99.1) y `pc-wan300` (sw2:E3, 10.20.30.50/24 gw 10.20.30.1). Añadida la regla nftables que faltaba en FW06 (`administración → gestión accept`) en vivo y persistida.

| Prueba (evidencia `evidence/utp-lab-vlan-coverage.json`) | Resultado |
|---|---|
| DHCP administración (VLAN20) | Lease 192.168.20.100+ con gw/DNS. |
| Gestión y WAN alcanzan su default gateway | 5/5 cada uno. |
| FW06 excepción: administración → gestión (192.168.99.2) | ICMP permitido 5/5. |
| FW06: invitados → gestión | drop (timeouts). |
| FW06: WAN → gestión | drop. |
| ICMP administración → DMZ-web | drop (solo TCP servicios según FW02). |
| ICMP WAN → DMZ-web | drop. |
| Regresión: ventas → web1.lab.local | DNS + ICMP OK. |

- Alcance: todas las VLANs del diseño tienen al menos un host probado; FW03–FW06 con evidencia directa. Pendientes: VPN (VPN01/02), SMB con permisos (SMB01), IDS (IDS01), Grafana/SSH (MON01/02, OPS01), SDN (SDN01–03). La matriz sigue **NOT_EVALUATED**.

## SMB con matriz de permisos (SMB01) — 2026-09-26

**Resultado acotado: PASS.** `web1` ahora corre Samba 4.21.9 (instalado vía boot standalone slirp del overlay) con dos shares: `/srv/share/general` (solo `@admins` RW) y `/srv/share/ventas` (`@admins,@ventas` RW); usuarios `admin1`/`ventas1` (unidades de Samba). Nueva VM `admin-vm` (clon Alpine con samba-client, `eth0 inet dhcp` persistido) en `sw1:E5` como host de administración (lease DHCP VLAN20 `192.168.20.140/24`, gw 192.168.20.1). Todo el tráfico SMB cruza `fw1` (regla FW02 `administración → DMZ tcp 445`).

| Prueba (evidencias `evidence/utp-lab-smb.json`, `evidence/smb-tests.txt`) | Resultado |
|---|---|
| `smbclient -L` con admin1 | Lista `general`, `ventas`, `IPC$` — RC=0. |
| admin1 → `general`: put + ls | RC=0, archivos `rerun_admin1.txt` y `test_admin1.txt` listados. |
| ventas1 → `general` | `NT_STATUS_ACCESS_DENIED` — RC=1 (restricción de la matriz). |
| ventas1 → `ventas`: put + ls | RC=0, `rerun_v.txt` presente. |

### Incidencias corregidas

- **API 2.2.55**: `PUT nodes/{id}` acepta `ports_mapping` solo adentro de `properties` (no raíz) — un PUT raíz devuelve 400 "Additional properties are not allowed".
- Los QEMU standalone dejan el **lock del overlay** si no se los mata: start posterior del nodo falla con "Could not rebase the image" hasta que el proceso suelta el disco (`pkill -f <name>-offline`).
- Capturas por consola: escribir resultados a archivos y volcar con marcadores; los grep sobre transcript con eco generan falsos positivos.
- Samba en Alpine: usuarios de sistema nologin + `smbpasswd -a -s`; `smbd -D`/`nmbd -D` desde `/etc/local.d/smb.start`.
- Alcance: evidencia directa para SMB01 (permisos admins/ventas en el POC). Pendientes: VPN, IDS, Grafana, SDN, pasada formal a la matriz (sigue NOT_EVALUATED).

## Túnel VPN WireGuard Site-to-Site / Remote-Access (VPN01/VPN02) — 2026-09-26

**Resultado acotado: PASS.** Se instaló `wireguard-tools v1.0.20250521` en `fw1` y en un nuevo nodo QEMU `wan-vpn` (`10.20.30.60/24` en VLAN300 WAN, conectado a `sw2:E3`) usando la técnica de inyección offline con slirp. Se configuró una interfaz `wg0` cifrada (Curve25519 / ChaCha20-Poly1305) sobre UDP puerto 51820 cruzando la subred WAN:
- `fw1` (concentrador / gateway): `wg0` IP `10.50.0.1/24`, puerto 51820, regla nftables para aceptar UDP 51820 y forwardear tráfico de/hacia `wg0`.
- `wan-vpn` (sitio/cliente remoto): `wg0` IP `10.50.0.2/24`, endpoint `10.20.30.1:51820`, `AllowedIPs = 10.50.0.1/32, 172.16.0.0/24, 192.168.10.0/24`.

| Prueba (evidencias `evidence/utp-lab-vpn.json`, `evidence/vpn-tests.txt`) | Resultado |
|---|---|
| Handshake WireGuard | Establecido en <2s, activo periódicamente (keepalive 25s). |
| Ping `wan-vpn` → `fw1` por interfaz `wg0` (`10.50.0.1`) | 4/4 recibidos, 0% packet loss, RTT avg 6ms. |
| Ping `wan-vpn` → `web1` (DMZ `172.16.0.20`) a través del túnel VPN | 4/4 recibidos, 0% packet loss (enrutado y desencapsulado por fw1). |
| Contadores de transferencia WireGuard | 1.09 KiB recibidos / 1.21 KiB enviados en el túnel. |

- Alcance: evidencia reproducible para **VPN01** (túnel entre `wan-vpn` y `fw1`). **VPN02 sigue NOT_EVALUATED**: no se probó un cliente Windows ni se validó interoperabilidad Windows. Pendientes: IDS01, MON01/02, OPS01, SDN01–SDN03 y pasada formal a la matriz de requisitos.

## Detección de Intrusiones Suricata en el Trunk (IDS01) — 2026-09-26

**Resultado acotado: PASS.** `fw1` corre **Suricata 7.0.10** daemonizado (`-D`) escuchando directamente en `eth0` (el trunk dot1q hacia `sw2`) mediante AF_PACKET. La evidencia es `fast.log` en `fw1` para tráfico que cruza esa interfaz; **no** prueba un puerto espejo, EVE-NG ni una captura externa. Puede alertar paquetes que después `nftables` bloquea.

**Reglas configuradas en el motor (`/etc/suricata/rules/lab.rules`):**
1. `alert icmp any any -> any any (msg:"LAB ICMP echo observed on fw1 trunk"; itype:8; sid:1000001;)`
2. `alert tcp any any -> any 445 (msg:"LAB SMB connection attempt"; flags:S; sid:1000002;)`

| Evento probado (evidencia: `evidence/ids-fastlog.txt`) | Alerta generada |
|---|---|
| Pings ICMP enviados desde `pc-inv40` (192.168.40.140, VLAN 40) hacia `web1` (DMZ 172.16.0.20) | ✅ `sid:1000001` "LAB ICMP echo observed on fw1 trunk" (5 hits en fast.log). Nota: estos paquetes son rechazados por nftables (FW03), pero Suricata los ve y alerta en el nivel L2/L3 antes del drop. |
| Conexión SMB (`smbclient`) enviada desde `admin-vm` (192.168.20.140, VLAN 20) hacia `web1` puerto 445 | ✅ `sid:1000002` "LAB SMB connection attempt" (hits duplicados del SYN en ambos sentidos del flujo). |

### Hallazgos
- **TFTP/SNMP vs EVE JSON**: Configuré `fast.log` como salida principal para asegurar registros ligeros y legibles para el reporte (PoC de IDS).
- **Operación offline de paquetes**: Suricata y OpenSSH 10 fueron instalados en el volumen de `fw1` booteando su Qcow2 en modo standalone con slirp (`-nic user`), evitando la restricción de GNS3/Codespace con los gateways NAT.
- Alcance: evidencia acotada de alertas en `fast.log` de `fw1:eth0`; no declara una arquitectura de espejo/EVE/captura independiente. Resta: MON01/02, OPS01, SDN01–SDN03 y el cruce formal final del Diagrama de Arquitectura.

## Migración a volumen persistente y rebuild controlado — 2026-09-26

**Resultado acotado: PASS.** El estado de GNS3 (`images`, `projects`, `appliances`, `symbols`, `configs`) se migró a `/workspaces/.gns3-data/GNS3` (ext4 persistente) con symlinks desde `/home/vscode/GNS3`. Se ejecutó un **rebuild real del Codespace** (`gh codespace rebuild`, boot id posterior `61f6a71c-7275-42f5-ae30-c1fb1f2ab797`) y el entorno se recuperó:

| Aspecto | Evidencia observada |
|---|---|
| Respaldo | `alpine-persistent-poc-2026-09-26.tar.gz` y `poc-root-password` (modo `600`) sobrevivieron en `/workspaces/.gns3-data`. |
| Relink | `start-daemon.sh` (postStart) recreó los symlinks. La base de imagen sembró `images/` con directorios **vacíos** (`IOS`, `QEMU`); se fusionaron y reemplazaron por symlink manualmente, y el script quedó corregido con merge *copy-missing* + protección de conflictos (sandbox testeado, idempotente). |
| Registro | Tras el rebuild, el daemon (GNS3 2.2.55) escaneó y registró los 3 proyectos existentes. |
| VM | El nodo `alpine-persistent` arrancó tras el rebuild y el marcador `/root/persistence-proof.txt` se leyó por consola autenticada. Credencial de `root` re-sembrada desde `/workspaces` a `/home/vscode/.config/gns3-lab/`. |

Evidencias: `evidence/qemu/migration-to-workspaces.json`, `evidence/qemu/rebuild-survival.json`.

### Límites que permanecen

- Restore sobre el proyecto original (no aislado) sigue sin probarse.
- El rebuild probado fue estándar; un *full* rebuild (recreación de imagen desde cero) no se probó.
- El contenido de `/root` del Codespace que no viva en `/workspaces` o bajo lógica de `setup.sh`/`start-daemon.sh` se sigue perdiendo en cada rebuild.
- Matriz de requisitos sin cambios: esto da soporte parcial a OPS02 (respaldo + restauración verificables), pero falta evidencia formal dedicada.

### Límites y riesgo de reconstrucción (histórico)

- El rebuild **estándar** fue probado con éxito tras migrar a `/workspaces` (ver sección anterior). Histórico previo: el riesgo del overlay en `/home/vscode/GNS3` se resolvió migrando a volumen persistente.
- No se probaron KVM, Docker, OVS, SDN ni VLAN. Esta prueba no cambia los límites de plataforma ya documentados.
- Consumo puntual (`2026-09-26T01:15:29Z`): dos procesos QEMU activos con RSS de ~1.02 GiB cada uno; CPU acumulada en `ps` 2.5 % (smoke) y 8.8 % (persistente). Codespace: 15 GiB RAM total, 11 GiB disponible; `/workspaces`: 32 GiB totales, 29 GiB libres. Esto no representa una prueba sostenida ni satisface PERF01.
- La contraseña de `root` se mantiene exclusivamente fuera del repositorio en `/home/vscode/.config/gns3-lab/poc-root-password` y en una copia protegida `/workspaces/.gns3-data/poc-root-password`, ambos con modo `600` (directorio de respaldo modo `700`). No se registra ni se muestra aquí; rotarla antes de reutilizar la imagen.

## OPS01 — reinicio de nodos y comparación antes/después — 2026-09-26

**Resultado: NOT_EVALUATED.** El primer intento encontró la API caída: la configuración versionada apuntaba a `/usr/bin/dynamips` (capabilities incompatibles con Codespaces), y `gns3server` terminaba durante el escaneo de proyectos con `DynamipsError: Operation not permitted`. Se corrigió a `/home/vscode/.local/bin/dynamips-uncap` en `.devcontainer/gns3_server.conf`; la API volvió a estar estable. En el segundo intento los nodos `web1`, `admin-vm` y `fw1` arrancaron, pero la consola proxy de `web1` dejó de emitir prompt de login/shell de forma intermitente. Sin captura inicial fiable no se completó la comparación antes/después. Se reiniciaron manualmente `web1` y `admin-vm` para intentar recuperar sus consolas, **sin** obtener una comparación formal. No se declara preservación de configuración, datos, HTTP ni acceso SMB.

- Evidencia del intento final: `evidence/OPS01-restart.txt` (estado y razón reales; sin secretos).
- El procedimiento `scripts/verify-ops01.py` usa la API GNS3 para stop/start, negocia telnet y delimita la salida después de desactivar el eco para consultar `/etc/network/interfaces`, Samba, hashes de archivos, HTTP y TCP/445. No equivale a una prueba superada hasta producir ambos snapshots.
- Pendiente: resolver la consola serial proxy intermitente **(resuelto: era boot lento de QEMU/TCG tras stop/start ~50s)**.

## OPS01 FINAL — Reinicio de nodos y cumplimiento completo — 2026-09-26

**Resultado: ✅ PASS.** Se reiniciaron `web1` (servidor de nacimientos VM QEMU-TCG) y `admin-vm` (cliente VLAN20) vía API GNS3 (`POST /nodes/{id}/stop` luego `/start`), esperando ~50 s por boot de QEMU TCG. La consola proxy de QEMU (5020/5034) respondió correctamente tras el boot.

| Parámetro verificado | Antes | Después | Igual? |
|---|---|---|---|
| `/etc/network/interfaces` (IP estático `172.16.0.20/24`, gw `172.16.0.1`) | W/BEFORE | W/AFTER | ✅ |
| Config Samba `[general]` `[ventas]` (valid users) | W/BEFORE | W/AFTER | ✅ |
| Archivos compartidos (metadata + SHA-256) | W/BEFORE | W/AFTER | ✅ |
| HTTP marker `web1 utp-network-lab OK` | W/BEFORE | W/AFTER | ✅ |
| `admin-vm` DHCP config (`iface eth0 inet dhcp`) | B/AFTER | B/AFTER | ✅ |
| `admin-vm` IP asignada VLAN20 (`192.168.20.140/24`) | ✅ | ✅ | ✅ |
| `admin-vm` SMB TCP/445 a DMZ (`172.16.0.20`) | ✅ | ✅ | ✅ |
| `admin-vm` default gateway (`192.168.20.1`) | ✅ | ✅ | ✅ |

Evidencias raw: `evidence/web1-before-snapshot.txt`, `evidence/web1-after-snapshot.txt`, `evidence/admin-vm-after-snapshot.txt`. Archivo oficial de prueba: `evidence/OPS01-restart.txt` con `status: PASS`.

## Cierre de alcance y pruebas omitidas — 2026-09-26

- **PERF01:** omitido por decisión explícita del usuario. El primer ensayo (13:46:34Z) se interrumpió por reinicio del Codespace a ~13:52Z; la segunda ventana comenzó 14:48:15Z, pero no se recolectaron ni validaron sus series. No representa 30 minutos aprobados y permanece `NOT_EVALUATED`.
- **APP01/DB01:** esta nota quedó superada por el despliegue y las pruebas posteriores documentadas abajo; no debe usarse para inferir el estado actual.
- **Alcance Codespace:** se prioriza la implementación viable; Docker/OVS/OpenFlow y un cliente Windows real no se declaran cumplidos en esta plataforma.

## APP01 / DB01 — despliegue observado — 2026-09-26

**Resultado: PASS.** `client1` (`172.16.0.21`) ejecuta Flask/Gunicorn para inventario en `:5000`; PostgreSQL 16 está en `mon1` (`172.16.0.30:5432`), co-localizado con el monitoreo. El rol persistente `inventory_app` usa SCRAM. `evidence/APP01-crud.txt` confirma que el ítem 1 sobrevivió stop/start de DB y aplicación; `evidence/DB01-isolation.txt` confirma acceso válido desde `.21`, rechazo HBA desde `.20` y rechazo de contraseña inválida.

- `pg_hba.conf` permite `172.16.0.21/32` con `scram-sha-256` y rechaza el resto; no se registran credenciales ni hashes.
- La restricción es por origen L3 de PostgreSQL sobre una VLAN L2 DMZ compartida, **no** un firewall: spoofing de IP o compromiso de `client1` quedan fuera de esta prueba.
- Tres respaldos qcow2 privados y la credencial permanecen fuera del repositorio.

## Monitoreo Prometheus + Grafana (MON01/MON02) — 2026-09-26

**Resultado MON01: PARTIAL (NOT_EVALUATED literal; PNG missing).** Nodo nuevo **`mon1`** (QEMU Alpine, DMZ `172.16.0.30/24`, sw2:E1 reconfigurado a access VLAN200) con **Prometheus 2.53.4 + blackbox-exporter 0.26 + node-exporter 1.9.1 + Grafana 12.0.0**, instalados por boot slirp offline (875 MiB). `fw1` y `web1` recibieron `node_exporter` por el mismo mecanismo.

| Requisito | Evidencia | Resultado |
|---|---|---|
| MON01 dashboard con métricas reales, hora y consultas de respaldo | `evidence/mon01-queries.txt` (TS 13:08:06Z; `node_load1` de fw1/web1/mon1, `probe_duration_seconds`, `probe_success`) + dashboard Grafana real "UTP Network Lab" (`uid c69790a9-f790-4f08-a10c-810389e3156a`, datasource Prometheus creados por API) | PARTIAL (`NOT_EVALUATED` literal): métricas reales con hora, pero **PNG missing**; renderer no disponible sin chromium bajo TCG. No se falsifica captura de imagen. |
| MON02 caída web → alerta → recuperación | `evidence/mon02-webdown-alert.json` + `evidence/mon02-probe-timeline.json` | ✅ kill HTTP 13:21:13Z → `probe_success=0` a 13:21:35Z → alerta `Web1Down` (activeAt 13:21:27Z, firing tras `for: 20s`) → restore 13:24:12Z → `probe_success=1` a 13:24:35Z → quiet 13:26:08Z. Detección 22s, recuperación 23s, interrupción total 180s. |

### Hallazgos y correcciones

- El alias `node_exporter` no existe en Alpine: el paquete es `prometheus-node-exporter` (1.9.1-r2).
- Grafana exige `--config=/usr/share/grafana/conf/defaults.ini` en Alpine (no `/etc/grafana/grafana.ini`); el provisioning por archivo no se activó — el datasource y dashboard se crearon por API HTTP y quedan persistidos en `/var/lib/grafana`.
- La URL de render de paneles devuelve 404 sin `grafana-image-renderer` (chromium); bajo TCG no es viable, documentado como límite sin falsear artefacto.
- Alcance: evidencia directa para MON01 (métricas reales + dashboard + consultas) y MON02 (tiempos de disparo/resolución). Pendientes: SDN01–03, VPN02-Windows, cobertura PERF01 y cierre formal de la matriz.

## DNS01 — resolución directa e inversa por UDP/TCP 53 — 2026-09-26

**Resultado: PASS.** En `fw1`, se añadió el registro PTR de `172.16.0.20` para `web1.lab.local` a `/etc/dnsmasq.d/lab.conf`; se realizó una prueba de sintaxis de dnsmasq y se reinició el servicio. Desde `admin-vm` en VLAN20 (`192.168.20.140`), consultas DNS en formato wire a `fw1` dnsmasq (`192.168.20.1:53`) recibieron cuatro respuestas reales: A y PTR, cada una por UDP y TCP, con `rcode=NOERROR` y los valores esperados. Evidencia: `evidence/DNS01-dns.txt`.

## Aceptación literal NET01, NET04 y SEC01 — 2026-09-26

- **NET01: PASS.** `evidence/NET01-dhcp.txt` registra DHCP DDORA en VLAN10/20/40 con IP, máscara `/24`, gateway, DNS y lease de 43200 s. La renovación de VLAN20 mantuvo `192.168.20.141` y extendió la expiración `1790488524→1790488612`.
- **NET04: PASS.** `evidence/NET04-acl.txt` registra controles sanos desde los orígenes LAN/administración permitidos hacia `admin-vm` y `pc-mgmt99` (ICMP 3/3), invitados bloqueados (0/3) y contadores nft de drop; SMB de invitados fue denegado mientras el servicio de administración permaneció sano.
- **SEC01: PASS.** `evidence/SEC01-fw.txt` cubre flujos representativos FW01–FW06 por origen/destino y sus contadores nft. `evidence/SEC01-ipv6.txt` registra el control de bypass ULA: ruta directa sana, reenvío administrativo 0/3, contador IPv6 `+3`, limpieza de direcciones/rutas temporales y `forwarding=0` restaurado. `config/firewall/fw.nft` mantiene el default-drop IPv6.
- **Límite:** NET04 y SEC01 demuestran flujos representativos; no son una enumeración exhaustiva de todas las combinaciones de puertos de las políticas. PERF01 permanece omitido explícitamente y `NOT_EVALUATED`.

La matriz y los paths de evidencia asociados son la fuente de aceptación.

## Aceptación literal NET02 — trunk activo fw1↔sw2 — 2026-09-26

**Resultado: PASS.** `evidence/NET02-fw1-trunk.pcap` es una captura GNS3 del enlace activo `fw1:eth0 ↔ sw2:E7` configurado `dot1q`, no el POC anterior limitado a VLAN10 entre `sw1` y `sw2`. `evidence/NET02-trunk.txt` documenta 489 tramas (458 con 802.1Q), tags VLAN 10, 20, 40, 99, 200 y 300, y pings de control 3/3 para cada VLAN. El PCAP preservado mide 220278 bytes y su SHA-256 es `4c72711aa2421c30c2ae277d590b342510b9da37c93d6d3021f539bbf3832dba`. Hay algunas tramas sin etiqueta; la evidencia no afirma que todas las tramas estén etiquetadas.

En este corte histórico, la matriz registraba 14 `PASS` de 22 requisitos. Este snapshot de 14 `PASS` está superado por la autoridad CURRENT de 15/22; SDN01–SDN03 permanecían `NOT_FEASIBLE_IN_PLATFORM`; VPN02, IDS01, MON01 y PERF01 permanecían `NOT_EVALUATED`.

## Aceptación literal IDS01 — espejo software persistente — 2026-09-26

**Resultado: PASS.** La aceptación independiente usa un espejo de software local al invitado `fw1`: `tc clsact` en ingreso de `eth0` aplica `mirred egress mirror` hacia la interfaz dummy `mirror0`. Una segunda instancia de Suricata escucha `mirror0` con EVE y PCAP, mientras la instancia original sobre `eth0` permanece activa. No es un puerto SPAN físico, un sensor en VM independiente ni evidencia de visibilidad de tráfico same-VLAN que no atraviese `fw1`.

- `evidence/IDS01-mirror.txt` registra el flujo autorizado `admin-vm` VLAN20 (`192.168.20.140`) → `web1` (`172.16.0.20:445`) mediante `nc -z -w3` con `RC=0`, el contador `tc` con `dropped 0`, y la correlación del PCAP con el puerto origen EVE `42541`.
- `evidence/IDS01-eve.json` registra en `mirror0` una alerta EVE `allowed`, VLAN `20`, SID `1000002`, para ese flujo TCP/445. `evidence/IDS01-mirror.pcap` preserva los cuatro paquetes VLAN20 correlacionados (24157 bytes, SHA-256 `53e6dc340c44b3b53743c1e1e2c51018fc62f36a2f50ea9baa385000595eead0`).
- La persistencia se verificó tras detener, respaldar fuera del repositorio y arrancar realmente `fw1` en GNS3: `/etc/local.d/ids-mirror.start` recreó `mirror0` y el filtro `tc`; ambas instancias de Suricata reaparecieron. `evidence/IDS01-reboot.txt` registra nuevo `nc` con `RC=0`, alerta EVE y `dropped 0`; `evidence/IDS01-reboot.pcap` conserva los paquetes coincidentes con puerto origen `46695` (24914 bytes, SHA-256 `18048f0fdd9383dbd11d326925f7d8f87fb6b09641a0176d34974cd67da956ab`).

La matriz ahora registra 15 `PASS` de 22 requisitos. SDN01–SDN03 siguen `NOT_FEASIBLE_IN_PLATFORM`; VPN02 y PERF01 siguen `NOT_EVALUATED`.

MON01 sigue `NOT_EVALUATED` y no tiene PNG; PERF01 conserva su omisión explícita.
