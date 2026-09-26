# deploy/host — capa Docker local (Plano B) complementaria del lab migrado

Este directorio levanta la **capa Docker nueva** que el Codespace no dejaba correr.  
Corre **en paralelo** con el lab QEMU/OJS importado del Codespace (Plano A); no reemplaza nada.

## Requisitos día uno

- `scripts/preflight-host.sh` completado con GO.
- Lab Codespace importado y corriendo (proyecto `utp-network-lab` vía bundle exportado).
- `docker compose` instalado en el WSL2 Ubuntu.

## Levantar plano SDN base (controller + 2×OVS)

```bash
docker compose -f deploy/host/docker-compose.sdn.yml up -d --build
docker compose -f deploy/host/docker-compose.sdn.yml ps
bash ../scripts/verify-stage4.sh      # checks de trunks y aislamiento
bash ../scripts/verify-stage5.sh      # gateway multi-VLAN + nftables base
```

## Segmentos usados (sin conflicto con el lab migrado)

| Red | Segmento | Quién la usa |
|---|---|---|
| OOB control | `172.29.250.0/24` | controller `.10`, SW1 `.11`, SW2 `.12` |
| VPN túnel | `10.250.0.0/24` | gateway `.1`, cliente `.2` |
| VLANs nuevas (etapa 4) | `10.10.x.0/24` | ejemplo de la capa Docker; se ajusta para **no** duplicar VLANs vivas |

Las VLANs `192.168.x.x`, `172.16.0.x`, `10.20.30.x` siguen siendo exclusivas del lab migrado.

## Etapas ya versionadas

- `../scripts/build-images.sh` — compila lo que ya da Dockerfile, con tag fijo `1.0.0`.
- `docker-compose.sdn.yml` — controller + 2×OVS con healthchecks y dependencias de servicio saludable.
- `../scripts/verify-stage4.sh` / `verify-stage5.sh` — validaciones ejecutables.
- Protocolos según spec §4: OpenFlow 1.3; fail‑mode `secure`.

## Lo que viene en etapas 6+ (previsto, no ejecutado)

- Matriz SEC01 completa (FW01‑FW06) en el nuevo firewall.
- OpenVPN en todos los puntos exigidos del spec.
- Aplicación inventario + PostgreSQL + Nginx, compartidas con repo.
- Prometheus + Alertmanager + Grafana + métricas SDN.
- Pruebas PERF01 30′ y MON01 con PNG (renderer disponible localmente).
