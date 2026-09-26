# deploy/host — etapa 2 (SDN plane) sobre Docker local

Este directorio arranca **solo el plano de control/datos SDN** del laboratorio local WSL2.
Requisitos: haber corrido `scripts/preflight-host.sh` con GO.

## Objetivo

- 2× Open vSwitch (OVS-SW1: `172.29.250.11`, OVS-SW2: `172.29.250.12`) con datos de trunks VLAN
- 1× Controlador Ryu (`172.29.250.10`) sobre TCP 6653
- Red OOB dedicada `172.29.250.0/24` (sin tráfico de usuario)

## Imágenes esperadas (fijas, no `:latest`)

| Imagen | Tag | Provino de |
|---|---|---|
| `lab-controller` | `1.0.0` | `controller/Dockerfile` |
| `lab-ovs` | `1.0.0` (a completar) | hosts OVS genéricos Alpine |

A completar en esta etapa si no están en repo: `docker/ovs/Dockerfile` (Alpine+openvswitch, entrypoint controlado).

## Levantar

```bash
docker compose -f deploy/host/docker-compose.sdn.yml up -d --build
docker compose -f deploy/host/docker-compose.sdn.yml ps
```

## Validación mínima antes de seguir

- `docker compose -f deploy/host/docker-compose.sdn.yml logs controller` muestra `ryu-manager` iniciado.
- En cada OVS, `ovs-vsctl show` debe listar el bridge y el `Controller` en modo `secure`.
- Debe existir conexión OpenFlow 1.3 a `172.29.250.10:6653`.

Detenga todo si el GO de `preflight-host.sh` no fue claro. No instalar sleeps ciegos: usar healthchecks con timeout.
