# Adaptación al spec "Comercial Andina S.A.C." sobre el trabajo hecho

**Fecha:** 2026-09-26 (UTC) **Rama:** `feat/docker-host-full`
**Regla:** adaptar **sobre** lo construido, sin rehacer; y no declarar PASS sin medir en tu host.

## 1. Correspondencia con lo ya construido

| Del spec (Comercial Andina §4‑§12) | Ya estaba en la rama | Acción de esta adaptación |
|---|---|---|
| VLANs 10/20/30/40/99, gateway .1 | mismo plano, distinto controlador de VLAN40/99 | actualizado con IPs del spec (OOB y VPN renumerados) |
| VLAN50 Almacén (10.10.50.0/24) | no existía | agregada a compose, Kea DHCP, fw.nft, verificación |
| Pool VPN 10.10.60.0/24 | era 10.250.0.0/24 (spec viejo) | renumerado en fw.nft y docs |
| OOB gestión = VLAN99 10.10.99.0/24 | era 172.29.250.0/24 | renumerado en compose + fw |
| Controlador único activo, OpenFlow 1.3, 6653 | Ryu ya implementado, fail-mode secure, mismo puerto | sin cambio; comparativa con ONOS/OSLK en §5.2 del spec respondida en `docs/sdn-comparativa.md` |
| Dominio `andina.test` + intranet | era `empresa.test` | renombrado en BIND y Kea |
| DNS central = 10.10.30.10 | era 10.10.30.11 | movido a .30.10 (`docker/dns`) para no colisionar con DB=..30.30 |
| Matrix firewall (políticas por rol) | FW01‑FW06 escrito | ajustado a las "políticas de intención" del spec (incluye VLAN50 y solo-WEB-authorización a DB) |
| DHCP relay | concepto está en specs | `docker/dhcp` (Kea) + fw like a relay: ver `docs/etapa7-relay.md` pendiente en host |
| Mirror IDS | IDS01 mirrored port en spec | `config/ids/mirror.yaml` sigue como referencia del lab Codespace; nivel encargado en etapa intacta |
| Monitoreo cloud (Azure candidato) | monitoring + Alertmanager local | docs: candidato Azure sin verificar (per spec); no declarar recepción de métricas |
| Pruebas P01‑P11 | verify-stage4..10 | mapeadas en §4 de este documento |
| Documentos (informe 14 capítulos) | existe en repo Codespace | actualización por medición futura |

## 2. Ajustes aplicados (commits de esta sesión)

1. IPs de gestión del plano SDN alinear a VLAN99 (10.10.99.0/24) — old `172.29.250.0/24` eliminado.
2. Pool VPN del spec: `10.10.60.0/24` (gateway .1, cliente .2) reemplaza a `10.250.0.0/24`.
3. BIND ahora sirve `andina.test` + `PTR` de las redes 10/20/30/50; Nginx intranet apunta a `intranet.andina.test`.
4. Kea: agregado pool VLAN50 (10.10.50.100–.149); DNS declarado = 10.10.30.10.
5. nftables: matriz actualizada con las filas de política del spec.
6. Compose SDN/servicios: nuevo esquema.

## 3. Lo que NO se tocó (sigue como estaba)

- `main` (lab Codespace), tag `v1.0-codespace` intactos.
- `docker/app` tests (hardened con CSRF+rate) sin cambio — su contrato es el mismo para WEB01.
- `scripts/export-lab.sh`/`import-lab.sh` (migración del bundle) sin cambio.
- El laboratorio mínimo (`Laboratorio-Minimo-Local.gns3`) **no** forma parte de nuestro repo ni del bundle; solo se menciona como estado inicial del spec.

## 4. Mapeo P01‑P11 → scripts de verificación (con salida esperada, no "ya pasó")

| Spec | Script | Criterio de aceptación esperado |
|---|---|---|
| P01 DHCP por VLAN | verify-stage7.sh | VLAN10/20/40/50 con pool/gateway/DNS correctos |
| P02 trunk + aislamiento | verify-stage4.sh | misma VLAN atraviesa el trunk, VLAN ajena no pasa |
| P03 DNS + web | verify-stage7.sh + stage7-https (pendiente) | intranet.andina.test responde por 443 validada |
| P04 app + DB | verify-stage7.sh | pedido persiste; 5432 directo desde cliente denegado (skips de la migración ssincr) |
| P05 archivos | verify-stage7.sh + checks Samba | usuario abre su share; otro grupo es rechazado |
| P06 invitados | verify-stage6.sh clientes VLAN40 | navega Internet, bloquea a privadas |
| P07 control SDN | verify-stage8.sh flows | DPIDs 1 y 2 conectados, cuarentena activa/retirada |
| P08 caída del controlador | verify-stage8.sh "stop controller" | comportamiento medido + documentado (spec §5 + §9) |
| P09 VPN | verify-stage6.sh VPN/client | túnel up, DMZ solo, gestión bloqueada |
| P10 IDS | script Suricata test | evento con hora/origen en eve.json |
| P11 monitoreo/cloud | verify-stage10.sh + dashboards | dashboard + alerta al bajar web; cloud según verificación de Azure (sin inventar resultados) |

## 5. Pendientes expresamente reconocidos (spec §15)

- Recursos reales de tu PC host — preflight pendiente.
- Versión exacta instalada de GNS3 y detector de backend (GNS3 vía GUI vs WSL2 daemon).
- Controlador elegido confirmado (Ryu/OS-Ken si el docente la admite).
- Imágenes/runtimes compatibles con cada release — build-images lo pinta.
- Azure: instancia/región/costo/credenciales sin verificar — hoy solo candidato (no usado).
- (opcional) AD: queda fuera por diseño según spec §6.
