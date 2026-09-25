# Laboratorio de Red Empresarial en GitHub Codespaces + GNS3

Proyecto académico de laboratorio de red empresarial implementado en un GitHub Codespace hosteando GNS3 Server con virtuales Docker (Conceptos: VLANs 802.1Q, SDN/OpenFlow, Security, VPN, Monitoreo).

- **Codespace activo:** `cuddly-bassoon-966v6pj7pvwphp9wj`
- **Repo:** https://github.com/lflores19/gns3-codespace-ssh

## Estructura

- `.devcontainer/` — Entorno completo de base en codespaces.
- `config/lab.yaml` — Fuente única de redes, nodos, roles y puertos.
- `docker/` — Dockerfiles por rol (web, app, db, dns, dhcp, samba, vpn, ids).
- `controller/` — App y políticas SDN (OpenFlow 1.3 / Ryu).
- `gns3/` — Proyecto, templates y scripts de API.
- `scripts/` — Scripts de automatización (ciclo de vida del lab).
- `docs/` — Informe de 14 apartados y matriz de requisitos (matriz-requisitos.csv).
- `evidence/` — Pruebas de aceptación.

## Uso rápido (dentro del Codespace)

```bash
cd /workspaces/gns3-codespace-ssh
./scripts/preflight.sh        # Diagnóstico inicial (Fase 1)
./scripts/build.sh            # Construcción de nodos Docker
./scripts/create-lab.py       # Levanta la topología en GNS3 vía API
./scripts/start-lab.sh        # Arranca los nodos de topología
./scripts/status.sh           # Chequeo de salud de nodos y servicios
./scripts/test-lab.sh         # Ejecuta matriz de pruebas (NET01, SEC01, MON01...)
```

## Uso desde máquina local (Windows / Linux / Mac)

1. **Establecer túneles** (PowerShell o Bash):
   ```bash
   gh codespace ports forward 3080:3080 5000:5000 5001:5001 5002:5002 5003:5003 -c cuddly-bassoon-966v6pj7pvwphp9wj
   ```
   O bien usa el script seguro: `./scripts/tunnel-windows.ps1` (ejecutar desde PowerShell en Windows).

2. **Cliente GNS3 Desktop:** Preferences → Server → Main Server: `127.0.0.1:3080`.

3. **SSH directo:** `gh codespace ssh -c cuddly-bassoon-966v6pj7pvwphp9wj`.

## Fases del laboratorio (9 fases definidas en el prompt de proyecto)

1. **Diagnóstico** — reconocer entorno, IPs, puertos, herramientas disponibles.
2. **Infraestructura base** — Compose, redes Docker, GNS3 daemon, nodos.
3. **Direccionamiento IP/VLANs** — kea-dhcp, 802.1Q.
4. **Servicios y Apps** — web, app, db, dns, samba.
5. **SDN / Seguridad / VPN / IDS** — OpenFlow, filtros, firewall, OpenVPN, Suricata.
6. **Monitoreo** — Prometheus / Grafana.
7. **Pruebas de Aceptación y Soporte** — scripts test-lab.sh.
8. **Informe Académico** — Informe de 14 apartados en docs/informe.md.
9. **Cierre** — Presentación, métricas, conclusiones.
