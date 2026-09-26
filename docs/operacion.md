# Operación segura del POC QEMU persistente

Este procedimiento consulta o inicia el nodo persistente `qemu-persistent-poc` dentro del Codespace. Ejecutá los comandos desde tu equipo con `gh codespace ssh`; no incluyen la contraseña de `root` en argumentos ni archivos versionados. La consola usa Telnet sobre `127.0.0.1` **dentro** del Codespace, transportado por SSH cifrado desde tu equipo; no expongas ese puerto públicamente.

> **Entrypoints retirados — no ejecutar:** `scripts/build.sh`, `scripts/start-lab.sh` y `scripts/provision-phase2.sh` son caminos legacy de Docker/provisioning. Usá la configuración/inicio de daemon de `.devcontainer` y el runbook QEMU actual. `scripts/test-lab.sh` no demuestra que el lab actual esté probado.

## Consulta y arranque

En Bash (Linux/macOS), definí el identificador del Codespace y consultá primero el estado. En PowerShell, usá `$CODESPACE = 'cuddly-bassoon-966v6pj7pvwphp9wj'` en lugar de `export`:

```bash
export CODESPACE="cuddly-bassoon-966v6pj7pvwphp9wj"
gh codespace ssh -c "$CODESPACE" -- 'curl -fsS http://127.0.0.1:3080/v2/projects/a8ca363c-cbe7-45f1-9918-4e07af1137c5/nodes/ce992561-7843-42be-a635-d12c9c09bb06'
```

Si la respuesta indica que el nodo está detenido, iniciarlo por la API local de GNS3:

```bash
gh codespace ssh -c "$CODESPACE" -- 'curl -fsS -X POST http://127.0.0.1:3080/v2/projects/a8ca363c-cbe7-45f1-9918-4e07af1137c5/nodes/ce992561-7843-42be-a635-d12c9c09bb06/start'
```

## Consola serie

La prueba observó el puerto de consola 5004. Abrí una sesión interactiva; ingresá las credenciales sólo cuando la consola las solicite y nunca las incluyas en comandos, historial ni archivos del repositorio.

```bash
gh codespace ssh -c "$CODESPACE" -- -t 'telnet 127.0.0.1 5004'
```

Dentro del invitado, la comprobación no sensible es:

```sh
cat /root/persistence-proof.txt
```

El resultado esperado del POC es `persistent-proof-2026-09-26`.

## Respaldo y límites

El respaldo verificado está en `/workspaces/.gns3-data/alpine-persistent-poc-2026-09-26.tar.gz`, con SHA-256 `10d9f9094a49dc30f0f675491d2a92dd487170be6c342993a12660daf877f5ab`. Fue creado con el invitado sincronizado y detenido; el invitado fue reiniciado después.

La contraseña de esta VM se conserva fuera del repositorio en `/workspaces/.gns3-data/poc-root-password` (directorio modo `700`, archivo `600`); no la imprimas ni la compartas y rotala antes de reutilizar la imagen.

## Restauración (probada en copia aislada)

El respaldo `/workspaces/.gns3-data/alpine-persistent-poc-2026-09-26.tar.gz` fue verificado por SHA-256 y restaurado con éxito como proyecto aislado `qemu-persistent-restore-test-2026-09-26` (evidencia `evidence/qemu/restore-test.json`). Procedimiento observado:

1. Verificar SHA-256 y extraer a staging temporal.
2. Restaurar sobre identidades nuevas: proyecto/node UUID nuevos, nombre nuevo, overlay rebasado con `qemu-img rebase -u` a una copia de la imagen base. Nunca sobrescribir proyectos ni imágenes en uso.
3. Reiniciar `gns3server` para que registre el proyecto (el API no expone import/load válidos en servidor no-local).
4. Abrir el proyecto, leer la consola real por API y arrancar el nodo; verificar datos.

Queda **sin probar**: restaurar sobre el proyecto original, y un *full rebuild* (recreación total de imagen). El rebuild estándar quedó probado el 2026-09-26: el estado de GNS3 vive en `/workspaces/.gns3-data/GNS3` y `start-daemon.sh` recrea los symlinks automáticamente (ver `docs/estado.md`).
