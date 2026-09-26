# GUÍA DE CONTEXTO — leer antes de tocar nada en este repo

> Este archivo existe **para evitar confusiones como la que ya tuvimos** ("completar con Docker" ≠ "reconstruir todo en Docker"). Es el contrato de la siguiente sesión.

## 1. Decisiones establecidas (no reabrir sin motivo)

| # | Decisión |
|---|---|
| D1 | Se abandona GitHub Codespaces como runtime. La plataforma fue probada y no soporta Docker/OVS/SDN (ver `docs/preflight.md`, historial `14e18ce`/`c41fdb0`/`f1def6c`/`eefb816` y evidencia viva registrada). **No reabrir esto.** |
| D2 | El laboratorio del Codespace (`main`, tag `v1.0-codespace`) es **definitivo** — se conserva intacto como fase 1 histórica con sus logros evidenciados. |
| D3 | El destino es **PC local Windows + WSL2 Ubuntu + Docker**, todo local, sin SSH a ninguna otra máquina. |
| D4 | La migración es **vía clonación del repositorio**: `git clone` → `git checkout feat/docker-host-full` → preflight → importar bundle de GNS3 exportado con `scripts/export-lab.sh` (backups qcow2 se copian fuera de git). |
| D5 | El plano Docker local **COMPLEMENTA** el lab migrado: cumple los requisitos del prompt original que el Codespace no dejaba (ENV02, SDN01‑03, OpenVPN, Kea/BIND9, Alertmanager, PERF01, etc.). No reemplaza segmentos ni host del lab importado. |

## 2. Qué es qué en este repo

| Rama/Archivo | Rol |
|---|---|
| `main` | Lab Codespace verificado (15/22 PASS, con `evidence/`, `matriz-requisitos.csv`, `informe.md`). No tocar runtime: ya está documentado. |
| `feat/docker-host-full` | Trabajo nuevo: plano Docker local en **paralelo** al lab migrado. |
| `scripts/export-lab.sh` / `import-lab.sh` | Piñón de la migración (bundle portable + qcow2 por fuera de git). |
| `scripts/preflight-host.sh` | GO/NO-GO del host local — se ejecuta en tu WSL2 Ubuntu. |
| `deploy/host/docker-compose.sdn.yml` | Capa Docker SDN nueva (Eth0=OOB, Eth1=trunk, subinterfaces en fw). |
| `deploy/host/docker-compose.services.yml` | VLAN30 del plano Docker: web+app+db+dns+dhcp+samba. |
| `docker/ovs|vpn|dhcp|dns|db|samba`, `monitoring/` | Config de los nuevos containers. |
| `scripts/verify-stage{4,5,6,7,8,10}.sh` | Chequeos ejecutables de cada etapa. |

## 3. Cosas que NO son

- ❌ No reconstruimos el lab QEMU/Dynamips del Codespace de cero en Docker: usa su bundle exportado.
- ❌ No cambiamos los segmentos `192.168.x`, `172.16.0.x`, `10.20.30.x` del lab migrado.
- ❌ No agregamos Docker al Codespace actual (ya probado imposible; ver §1 D1).
- ❌ No prometeremos PASS sin evidencia de ejecución en tu host.

## 4. El esquema de direccionamiento vigente

| Segmento | Uso | Dueño |
|---|---|---|
| `192.168.x.x`, `172.16.0.x`, `10.20.30.x` | VLANs servidores | lab migrado (Plano A) |
| `172.29.250.0/24` | control OOB (ctrl .10, SW1 .11, SW2 .12) | plano Docker (Plano B) |
| `10.250.0.0/24` | túnel OpenVPN (`.1`,` .2`) | plano Docker (Plano B) |
| `10.10.10.0/24`, `10.10.20.0/24`, `10.10.30.0/24`, `10.10.40.0/24`, `10.10.99.0/24` | VLANs del plano Docker (spec §5) | plano Docker (Plano B) |

Siempre comprobar solapamientos antes de aplicar cambios.

## 5. COMO completar el desdiamancheo en el futuro (cuando ya tengas el host)

1. Correr `scripts/preflight-host.sh` y pegar la salida.
2. Ejecutar `scripts/export-lab.sh` en el Codespace (ya probado) y copiar el bundle + `.gns3_private_backups` a tu PC.
3. `scripts/import-lab.sh <bundle>` en la PC → máquina levanta `utp-network-lab` con los 15 nodos originales.
4. `scripts/build-images.sh` → etapa 2 (Docker تعملا).
5. `docker compose -f deploy/host/docker-compose.sdn.yml up -d --build` → etapa 3-5 SDN (verificar con verify-stage4/5).
6. `docker compose -f deploy/host/docker-compose.services.yml up -d` → VLAN30 (verify-stage7).
7. Matriz SEC01 + OpenVPN → verify-stage6. fmt.
8. Monitoreo, PERF, SDN02/03 → verify-stage8/10.
9. Actualizar `docs/matriz-requisitos.csv` solo cuando haya evidencia.

## 6. Patrones que deben seguirse

- Versionados con ramas: paralelo al trabajo nuevo, `main` queda inalterado.
- Cada etapa: artefacto + script de verificación ejecutable.
- Números de segmento y contratos sacados del prompt original (§4-§11) o de la evidencia del Codespace; **no presuponer**.
- Si algo "no se pudo", marcar `NOT_FEASIBLE_IN_PLATFORM` + documentar razón (ver matriz histórica); no solo decir que está mal.
