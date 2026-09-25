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
