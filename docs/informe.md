# Informe académico — laboratorio de red empresarial

**Resultado:** el laboratorio es viable como emulación GNS3 en Codespaces, no como plataforma Docker/OVS/OpenFlow. La aceptación literal independiente aprueba NET01, NET02, NET03, NET04, DNS01, APP01, DB01, SMB01, SEC01, VPN01, IDS01, MON02, OPS01, OPS02 y OPS03 (15 PASS de 22 requisitos); la matriz es la fuente de estado verificable.

## 1. Objetivo y alcance
Se evaluó una red empresarial acotada en GitHub Codespaces con GNS3. El objetivo fue observar conectividad, segmentación, servicios de red, seguridad y operación sin declarar capacidades no demostradas.

## 2. Plataforma de ejecución
GNS3 2.2.55 ejecuta QEMU con TCG, sin KVM, y Dynamips/EtherSwitch. La ausencia de CAP_NET_ADMIN/CAP_SYS_ADMIN impide Docker utilizable, datapaths OVS y puentes/TAP; el diagnóstico está en `docs/preflight.md` y `docs/estado.md`.

## 3. Arquitectura implementada
Los nodos QEMU Alpine proporcionan servicios; VPCS representa clientes. Dynamips aporta dos switches Ethernet y `fw1` actúa como router-on-a-stick. La persistencia se apoya en discos qcow2 y datos de GNS3 en el volumen de trabajo.

## 4. Topología y VLAN
El diseño contempla VLAN 10 (ventas), 20 (administración), 40 (invitados), 99 (gestión), 200 (DMZ) y 300 (WAN). `fw1` termina subinterfaces y enruta los prefijos documentados en `docs/estado.md`. NET02 es `PASS`: `evidence/NET02-fw1-trunk.pcap` captura el enlace activo `fw1:eth0 ↔ sw2:E7` configurado `dot1q` (no el POC anterior sólo VLAN10), y `evidence/NET02-trunk.txt` registra los seis tags y pings de control 3/3 por VLAN. El PCAP mide 220278 bytes, SHA-256 `4c72711aa2421c30c2ae277d590b342510b9da37c93d6d3021f539bbf3832dba`; algunas tramas no están etiquetadas, por lo que no se afirma que todas lo estén.

## 5. Servicios de red
`fw1` ejecuta nftables con política de reenvío por defecto denegada y dnsmasq para DHCP/DNS. `evidence/NET01-dhcp.txt` verifica DDORA, IP, máscara `/24`, gateway, DNS y lease de 43200 s en VLAN10, VLAN20 y VLAN40; la renovación de VLAN20 mantuvo `192.168.20.141` y extendió la expiración `1790488524→1790488612`, por lo que NET01 es `PASS`. Tras añadir el PTR de `172.16.0.20` para `web1.lab.local` a `/etc/dnsmasq.d/lab.conf`, se realizó una prueba de sintaxis y se reinició dnsmasq. `evidence/DNS01-dns.txt` registra desde `admin-vm` VLAN20 cuatro respuestas DNS wire-format reales de `fw1` (`192.168.20.1:53`): A y PTR por UDP y TCP, todas `NOERROR`; DNS01 es `PASS`.

## 6. Seguridad y segmentación
Las reglas nftables permiten sólo los flujos definidos entre VLAN y bloquean los no permitidos. NET04 es `PASS` mediante `evidence/NET04-acl.txt`: ICMP desde los orígenes permitidos hacia `admin-vm` LAN y `pc-mgmt99` gestión fue 3/3, mientras invitados fue 0/3 con contadores nft de drop; SMB de invitados fue denegado y el servicio desde administración permaneció sano. SEC01 es `PASS` mediante `evidence/SEC01-fw.txt` y `evidence/SEC01-ipv6.txt`: flujos representativos FW01–FW06 por origen/destino tuvieron sus contadores, el bypass IPv6 ULA fue bloqueado (forward 0/3, contador `+3`) y se limpiaron direcciones/rutas temporales con forwarding restaurado a `0`; `config/firewall/fw.nft` conserva el guard de reenvío IPv6 por defecto denegado. La cobertura es representativa, no exhaustiva de toda combinación de puertos. **IDS01 es PASS** con un espejo software local al invitado `fw1`: `tc clsact` en ingreso de `eth0` usa `mirred egress mirror` hacia `mirror0`, donde una segunda instancia de Suricata genera EVE y PCAP; la instancia original sobre `eth0` sigue activa. `evidence/IDS01-mirror.txt`, `evidence/IDS01-eve.json` y `evidence/IDS01-mirror.pcap` correlacionan el flujo autorizado VLAN20 `admin-vm` → `web1:445` (`nc` RC=0), la alerta EVE `allowed` SID `1000002` en `mirror0`, el puerto origen `42541` y `tc` con `dropped 0`. Tras un stop/start real de `fw1`, `evidence/IDS01-reboot.txt` y `evidence/IDS01-reboot.pcap` demuestran que `/etc/local.d/ids-mirror.start` recreó espejo y segunda Suricata, con un nuevo flujo correlacionado (puerto `46695`) y `dropped 0`. No es SPAN de switch físico, una VM sensor independiente, ni prueba de tráfico same-VLAN que evite `fw1`.

## 7. Acceso remoto VPN
VPN01 es `PASS` con `evidence/VPN01-wan.txt`: el peer WAN y `fw1` mostraron handshake, IP y rutas activas; el acceso a DMZ fue permitido y el intento temporal hacia gestión fue denegado, con contador nft `wg0→management` de 0 a 3. La ruta y los `AllowedIPs` temporales se limpiaron y la configuración original se restauró. VPN02 no se evaluó porque no hubo cliente Windows.

## 8. Servicios de aplicación y datos
`client1` (`172.16.0.21`) ejecuta la aplicación de inventario Flask/Gunicorn en `:5000`; PostgreSQL 16 se ejecuta en `mon1` (`172.16.0.30:5432`), co-localizado con el monitoreo. `evidence/APP01-crud.txt` demuestra alta, lectura y persistencia del ítem 1 tras stop/start de DB y aplicación. `evidence/DB01-isolation.txt` demuestra autenticación SCRAM de `inventory_app` desde `.21`, rechazo HBA para `.20` y rechazo de contraseña inválida. APP01 y DB01 son `PASS`; la restricción HBA es L3 en una VLAN L2 compartida, no un firewall, por lo que no excluye spoofing de IP ni compromiso del host de aplicación.

## 9. Permisos SMB
La evidencia `evidence/smb-tests.txt` muestra acceso de administrador a los recursos y `NT_STATUS_ACCESS_DENIED` para el usuario no autorizado, además de escritura autorizada en el recurso de ventas. SMB01 cumple su criterio y es `PASS`.

## 10. Monitoreo
`mon1` ejecutó Prometheus, blackbox-exporter, node-exporter y Grafana. MON02 es `PASS`: la caída de HTTP, la alerta Web1Down y la recuperación tienen cronología en `evidence/mon02-webdown-alert.json` y `evidence/mon02-probe-timeline.json`.

## 11. Operación y recuperación
OPS01 es `PASS` mediante comparación antes/después de reinicios de `web1` y `admin-vm` en `evidence/OPS01-restart.txt`. OPS02 es `PASS` mediante restauración aislada y supervivencia de rebuild en `evidence/qemu/restore-test.json` y `evidence/qemu/rebuild-survival.json`. OPS03 es `PASS` mediante una consola VPCS de GNS3 por túnel SSH local Linux `127.0.0.1:15014` al Codespace `127.0.0.1:5014`, no por VPN de Windows (`evidence/OPS03-console.txt`).

## 12. Metodología
Se aplicó una auditoría literal: cada requisito exige su evidencia y criterio completos. Se revisaron artefactos existentes, se comprobó la factibilidad de plataforma y se evitaron inferencias desde pruebas parciales. La clasificación final está en `docs/matriz-requisitos.csv`.

## 13. Resultados y limitaciones
NET01, NET02, NET03, NET04, DNS01, APP01, DB01, SMB01, SEC01, VPN01, IDS01, MON02, OPS01, OPS02 y OPS03 son `PASS` (15 de 22 requisitos). ENV02 y SDN01–SDN03 son `NOT_FEASIBLE_IN_PLATFORM`. VPN02, MON01 y PERF01 siguen sin evaluar; MON01 carece de PNG y PERF01 fue omitido explícitamente, sin prueba de 30 minutos. SEC01 cubre flujos representativos por regla y pares origen/destino, no todas las combinaciones de puertos de cada política. No se declaran Docker build, OpenFlow, DNSSEC ni cliente Windows. APP01/DB01 están desplegados con respaldos qcow2 privados y credenciales fuera del repositorio; DB01 limita el origen con HBA+SCRAM, no con aislamiento de firewall.

## 14. Referencias
Las fuentes primarias de GNS3, Codespaces, WireGuard, Suricata, Prometheus y Grafana se listan en `docs/referencias.md`. Las evidencias locales y el estado de aceptación se consultan, respectivamente, en `evidence/` y `docs/matriz-requisitos.csv`.
