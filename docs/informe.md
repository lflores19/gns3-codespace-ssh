# Informe académico — Laboratorio de red empresarial (14 apartados)

> Redacción en progreso por fases. Cada sección mapea requisitos de `docs/matriz-requisitos.csv` con evidencias en `evidence/`.

## 1. Marco teórico
(Pendiente — se completará en Fase 8.) Contenido planificado: hipervisores tipo 1/2 vs contenedores; VLAN/802.1Q; SDN y planos datos/control/aplicación; OpenFlow; red tradicional vs SDN; OpenDaylight/ONOS/Ryu; firewall, IDS vs IPS, ACL, VPN; IaaS/PaaS/SaaS y monitoreo cloud.

## 2. Análisis de requerimientos
Base diagnóstica en `docs/preflight.md` (hardware medido del Codespace: 4 vCPU, 16 GB RAM). Presupuesto por rol en `config/lab.yaml`.

## 3. Diseño de red
Diagrama lógico planificado: PC local → GitHub Codespace → devcontainer/Docker + GNS3 (server 2.2.55) → VLANs 10/20/40/99/200/300. Distinción control/datos en SDN.

## 4. Servidores virtuales
DHCP (Kea), DNS (BIND9), Web (Nginx), App (Flask+inventario), DB (PostgreSQL 16), Archivos (Samba). Decisión de dominio: sin AD; resolución BIND9 interna `lab.local`.

## 5. VLAN
Tabla IP completa en `config/lab.yaml` (vlans 10/20/40/99/200/300). Evidencias: NET01–04.

## 6. SDN
Comparación OpenDaylight/ONOS/Ryu → selección Ryu (ligero, software-only, OF 1.3, apto para Codespace sin KVM). Pipeline y SDN02 bloqueo HTTPS Ventas reversible.

## 7. Seguridad
Matriz firewall FW01–FW06 (`config/lab.yaml`), ACL, VPN OpenVPN (VPN01/02), IDS Suricata modo monitor (IDS01), bypass IPv6 probado en SEC01.

## 8. Monitoreo en la nube
Stack autogestionado (Prometheus+Grafana en el Codespace, IaaS-hosted). Métricas, dashboards y alertas (MON01/02). No se usa SaaS externo; dependencias registradas.

## 9. Herramientas y tecnologías
Inventario implementado (Docker, GNS3, OVS, Ryu, Kea, BIND9, PostgreSQL, Samba, OpenVPN, Suricata, Prometheus, Grafana). Sin hipervisor bare-metal: la emulación es contenedores + Dynamips/QEMU-TCG.

## 10. Presupuesto opcional
Codespaces: máquina 4-core/16 GB; cuotas según facturación GitHub vigente (fecha: 2026-09). Costes de licencias: todo software OSS.

## 11. Pruebas y resultados
Tablas esperado/observado en `tests/acceptance.md` y `evidence/`. Estado por requisito en matriz CSV.

## 12. Conclusiones y recomendaciones
(Pendiente — derivadas de resultados.)

## 13. Bibliografía
Ver `docs/referencias.md` (fuentes primarias oficiales).

## 14. Anexos
Scripts, configs, capturas PCAP/EVE, flujos SDN sanitizados en `evidence/` y `gns3/`.
