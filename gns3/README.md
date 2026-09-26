# Nota — export del proyecto GNS3

El prompt original sugería alojar acá el proyecto/export. En esta versión, el export portable del proyecto se genera con `scripts/export-lab.sh` y se importa con `scripts/import-lab.sh` (ver `docs/deploy-en-otra-cuenta.md`). El proyecto activo (`utp-network-lab`) vive en el volumen persistente `/workspaces/.gns3-data/` del Codespace; no se versiona en git por contener imágenes y secretos.
