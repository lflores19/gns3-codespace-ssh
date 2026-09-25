# Estado del proyecto — utp-network-lab

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

1. dockerd arranca solo con `--bridge=none --iptables=false` (iptables/nftables no permitidos: falta CAP_NET_ADMIN en el contenedor codespaces: `capsh --print` muestra Bounding sin `cap_net_admin` ni `cap_sys_admin`).
2. docker build/pull falla: `unshare: operation not permitted` y overlayfs `mount ... operation not permitted` (sin CAP_SYS_ADMIN no hay user namespaces ni mounts privados).
3. openvswitch-switch 2.17.12 inicia, pero `ovs-vsctl add-br br0` no crea datapath (kernel module no gestionable) y `ovs-ofctl show br0` → "br0 is not a bridge". OVS userspace (netdev) también requiere tuntap → imposible.
4. GNS3 2.2.55 sí funciona (API OK, puerto 3080) — VPCS/Dynamips/EtherSwitch son vía UDP y no requieren NET_ADMIN.

Decisión de diseño (documentada en docs/arquitectura.md):
- **Plan B obligatorio**: nodos de servicios (web/app/db/dns/dhcp/samba/vpn) como procesos nativos del Codespace (apt/pip) o imágenes QEMU mínimas bajo GNS3; conmutación VLAN 802.1Q con EtherSwitch de GNS3 o IOU/Dynamips; SDN con OVS en Mininet standalone NO es viable → sustituir por Ryu + OpenVSwitch userspace no viable → SDN sobre switches virtuales de GNS3 + controlador externo queda restringido a protocolo de layer-2 (OpenFlow solo vía IOU L3? no). Registro de excepción: SDN01-03 pasarán a NOT_FEASIBLE_IN_PLATFORM salvo replanteo con EVE-NG/QEMU OVS image.
