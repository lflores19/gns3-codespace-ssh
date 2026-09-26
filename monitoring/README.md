# Nota — directorio histórico

Este directorio contenía el scaffold para el despliegue Prometheus/Grafana/Alertmanager previsto para el perfil Docker del prompt original. El lab actual usa QEMU/Dynamips; el monitoreo real corre en **mon1** (172.16.0.30) con Prometheus, blackbox-exporter, node-exporter y Grafana (sin Alertmanager, sin métricas de controlador SDN). Ver `evidence/mon01-queries.txt`, `evidence/mon02-*.json` y `docs/matriz-requisitos.csv` (MON01 `NOT_EVALUATED`, MON02 `PASS`).

No usar estos archivos como evidencia de despliegue en el runtime actual.
