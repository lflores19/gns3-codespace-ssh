# NOTA — imagen OVS por contenedor

Completa el Dockerfile concreto en fase "red" (etapa 3 de `docs/despliegue-host.md`). Sujeto a validación del preflight del host: OVS con datapath kernel vs. userspace está condicionado por `/dev/net/tun` y capacidades; el path elegido se documenta en el informe final (sin falsear aislamiento).
