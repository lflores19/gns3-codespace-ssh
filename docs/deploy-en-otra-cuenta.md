# Deploy en otra cuenta / otro Codespace

Este repo clona el **entorno** (devcontainer, docs, evidencias, configs) pero **no empaqueta el laboratorio vivo** (topología GNS3 + discos qcow2). Este runbook explica las dos vías para correr el lab en un destino nuevo.

## Qué SÍ obtiene un clone limpio

- `.devcontainer/`: postCreate instala GNS3 2.2.55, QEMU, Dynamips, VPCS; postStart religa persistencia bajo `/workspaces/.gns3-data`.
- Documentación completa (`docs/informe.md`, `docs/matriz-requisitos.csv`) y evidencias verificadas (`evidence/` con SHA-256 en `evidence/manifest.csv`).
- Snapshots de red: `config/firewall/fw.nft`, `config/dns/lab.conf`, `config/ids/mirror.yaml`.
- Skills con las recetas API (`skills/gns3-network-architect`, `skills/gns3-codespace-ops`).

## Qué NO está en git (a propósito)

- Imágenes qcow2 base y overlays de los guests.
- Proyecto GNS3 ejecutable (topología `.gns3` y `project-files/`).
- Secretos operativos: `poc-root-password`, claves WireGuard, contraseña DB `inventory_app`.
- PERF01 (omitido por decisión) y MON01 PNG (no disponible bajo TCG).

## Vía A — Reconstruir de cero (determinista y enseñanza)

1. Fork/clonar el repo y abrir un Codespace nuevo.
2. `bash .devcontainer/setup.sh` (ya corre postCreate) y `.devcontainer/start-daemon.sh` levanta el daemon con paths persistentes.
3. Usar `skills/gns3-network-architect/SKILL.md` (contrato REST API v2, templates QEMU/Dynamips) para crear nodos/enlaces/VPCs según `config/lab.yaml`.
4. Recrear guests: instalar Alpine en imágenes base (procedimiento de boot offline documentado en `docs/estado.md`) aplicando `config/firewall/fw.nft`, `config/dns/lab.conf` y `config/ids/mirror.yaml` con los runbooks (`docs/app-db-runbook.md`, `docs/ids-mirror-runbook.md`).
5. Generar credenciales nuevas (`poc-root-password`, WireGuard, DB `inventory_app`).

## Vía B — Migrar el lab existente (rápido)

1. En el Codespace **origen**: `./scripts/export-lab.sh [proyecto] [output]`.
   - Produce `export/utp-network-lab-export-<UTC>.tar.gz` + SHA-256 con topología + API refs; no incluye discos ni secretos.
2. Copiar el tar.gz al nuevo Codespace (`gh codespace cp` o `curl` dentro).
3. En el Codespace **destino**: `./scripts/import-lab.sh <ruta-al-tar.gz>`.
   - No sobreescribe proyectos existentes; requiere Codespace limpio para ese `project_id`.
4. Restaurar/copiar imágenes base a `/home/vscode/GNS3/images/` o `/workspaces/.gns3-data/GNS3/images/` (vía scp o rebuild de guests), luego iniciar nodos.
5. Regenerar secretos y validar contra la checklist de `evidence/`.

## Validación mínima post-migración

- API: `curl http://127.0.0.1:3080/v2/version` → 2.2.55.
- Nodos: 15 started; links ≥ 13; capturas en 0.
- Consolas perezosas al primer boot TCG son normales (1–2 min).
- Reejecutar los checks documentados en `docs/matriz-requisitos.csv` para producir evidencia nueva.

## Buenas prácticas

- No versionar jamas `poc-root-password`, claves WireGuard ni dumps con secretos.
- Antes de sobrescribir un destino, correr `git status` y un `sha256sum` de respaldo.
- PERF01 queda fuera del alcance entregado; si lo necesitás, correr la carga 30 min y registrar evidencias aparte.

## Referencias

- `README.md`, `docs/operacion.md`, `docs/ids-mirror-runbook.md`, `docs/app-db-runbook.md`, `config/lab.yaml`.
