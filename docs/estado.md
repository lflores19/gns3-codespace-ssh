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
