# Nota — directorio histórico

Scaffold SDN del prompt original (Ryu + Open vSwitch) previsto para nodos Docker. En este runtime (GNS3 2.2.55 + QEMU/TCG + Dynamips EtherSwitch en Codespaces sin CAP_NET_ADMIN) **no hay plano SDN desplegado**: SDN01–SDN03 están `NOT_FEASIBLE_IN_PLATFORM` en `docs/matriz-requisitos.csv`. El switching real está en Dynamips EtherSwitch con dot1q; el routing y filtrado en `fw1` (`config/firewall/fw.nft`).

No usar estos archivos como evidencia del runtime actual.
