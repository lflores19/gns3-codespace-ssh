# Guía Detallada de Construcción Manual: Red Empresarial SDN 100% en Docker

> **Propósito**: Documentar paso a paso, comando por comando, la construcción y el **porqué técnico y arquitectónico** de cada instrucción ejecutada en el despliegue de la red empresarial virtualizada con SDN en Docker.
> **Contexto de ejecución**: Host Linux local (o Ubuntu bajo WSL2) con Docker Engine instalado.
> **Rama de referencia**: `feat/docker-host-full`

---

## Índice

1. [Fase 0: Creación de Bridges y Dominios de Difusión](#fase-0-creación-de-bridges-y-dominios-de-difusión)
2. [Fase 1: Plano de Control SDN (Ryu Controller)](#fase-1-plano-de-control-sdn-ryu-controller)
3. [Fase 2: Switches Open vSwitch (SW1 y SW2)](#fase-2-switches-open-vswitch-sw1-y-sw2)
4. [Fase 3: Firewall Router-on-a-Stick (lab-fw1)](#fase-3-firewall-router-on-a-stick-lab-fw1)
5. [Fase 4: Servidores de Infraestructura y Aplicación (VLAN 30)](#fase-4-servidores-de-infraestructura-y-aplicación-vlan-30)
6. [Fase 5: Clientes por Departamento (VLAN 10, 20, 40, 50)](#fase-5-clientes-por-departamento-vlan-10-20-40-50)
7. [Fase 6: Pila de Monitoreo y Observabilidad (VLAN 99 / OOB)](#fase-6-pila-de-monitoreo-y-observabilidad-vlan-99--oob)
8. [Fase 7: Verificación Integral del Sistema](#fase-7-verificación-integral-del-sistema)
9. [Equivalencia con Docker Compose](#equivalencia-con-docker-compose)

---

## Fase 0: Creación de Bridges y Dominios de Difusión

En redes físicas, cada departamento se conecta a puertos de switch configurados en VLANs separadas, o a switches dedicados. En Docker, cada `network` de tipo `bridge` crea un puente virtual en el kernel de Linux (`br-xxxx`), actuando como un **dominio de colisión y difusión aislado**.

### 0.1 Red de Gestión Fuera de Banda (OOB - Out of Band)

```bash
docker network create --driver bridge \
  --subnet=10.10.99.0/24 --gateway=10.10.99.1 \
  lab-oob
```

* **¿Por qué `--subnet=10.10.99.0/24`?** El spec exige que el tráfico de control (OpenFlow, SSH de administración, scraping de Prometheus) viaje por un plano completamente aislado del tráfico de usuarios.
* **¿Por qué `--gateway=10.10.99.1`?** Define la IP del host/puente en este segmento para permitir comunicación local entre contenedores de gestión sin requerir enrutamiento por el firewall de datos.

### 0.2 Enlace Troncal entre Switches (Backbone L2)

```bash
docker network create --driver bridge --internal \
  --subnet=10.255.0.0/28 \
  lab-backbone
```

* **¿Por qué `--internal`?** Este bridge simula el cable de red directo entre SW1, SW2 y el Firewall. No debe tener salida a Internet ni gateway de Docker; solo transporta tramas Ethernet 802.1Q etiquetadas entre los switches y las subinterfaces del firewall.
* **¿Por qué `/28` en lugar de `/30`?** Un `/30` solo provee 2 IPs útiles (`.1` y `.2`). Como a este troncal se conectan 3 entidades (`sw1`, `sw2`, `fw`), se requiere al menos un `/28` (14 IPs útiles) para evitar agotamiento de direcciones durante el attach.

### 0.3 Segmentos de Acceso por Departamento

```bash
docker network create --driver bridge --subnet=10.10.10.0/24 lab-vlan10
docker network create --driver bridge --subnet=10.10.20.0/24 lab-vlan20
docker network create --driver bridge --subnet=10.10.30.0/24 lab-vlan30
docker network create --driver bridge --subnet=10.10.40.0/24 lab-vlan40
docker network create --driver bridge --subnet=10.10.50.0/24 lab-vlan50
```

* **¿Por qué redes `/24` separadas?** Cumple con la asignación del plan de direccionamiento:
  * `10.10.10.0/24` -> VLAN 10: Administración
  * `10.10.20.0/24` -> VLAN 20: Ventas
  * `10.10.30.0/24` -> VLAN 30: Servidores (Infraestructura, Web, DB, Archivos)
  * `10.10.40.0/24` -> VLAN 40: Invitados (acceso restringido a Internet)
  * `10.10.50.0/24` -> VLAN 50: Almacén / Logística

### 0.4 Red WAN de Laboratorio

```bash
docker network create --driver bridge --subnet=192.0.2.0/24 lab-wan
```

* **¿Por qué `192.0.2.0/24`?** Es el bloque TEST-NET-1 reservado por RFC 5737 para documentación y pruebas de laboratorio. Representa el enlace externo del firewall hacia Internet sin colisionar con redes domésticas ni corporativas.

---

## Fase 1: Plano de Control SDN (Ryu Controller)

En una red SDN, el plano de control (el cerebro) debe estar activo antes que los switches (el plano de datos), para que cuando los switches arranquen y negocien OpenFlow, el socket TCP esté disponible y se instalen los flujos base.

```bash
# 1.1 Construir la imagen del controlador Ryu
docker build -t lab-controller:1.0.0 ./controller
```

* **¿Por qué se construye desde `./controller`?** Instala `ryu`, `eventlet==0.30.2`, `netcat-openbsd` y copia las aplicaciones OpenFlow `simple_switch_13.py` y `sd_policies.py`.

```bash
# 1.2 Ejecutar el contenedor del controlador en la red OOB
docker run -d \
  --name lab-ctrl1 \
  --network lab-oob \
  --ip 10.10.99.10 \
  -p 127.0.0.1:6653:6653 \
  --restart unless-stopped \
  lab-controller:1.0.0
```

* **¿Por qué `--ip 10.10.99.10`?** Asigna la IP fija exigida por la especificación para el controlador en la red de gestión.
* **¿Por qué `-p 127.0.0.1:6653:6653`?** Expone el puerto OpenFlow estándar (IANA 6653) únicamente en el localhost del host para depuración, evitando exponer el plano de control a interfaces públicas.
* **¿Por qué `--restart unless-stopped`?** Garantiza que si el contenedor falla o el daemon de Docker reinicia, el controlador se levante automáticamente antes de que los switches entren en timeout.

```bash
# 1.3 Verificar que el socket OpenFlow esté escuchando
docker exec lab-ctrl1 nc -z 127.0.0.1 6653 && echo "Ryu Controller listo en 6653"
```

* **¿Por qué este check?** Valida que el proceso `ryu-manager` no haya crasheado al cargar las dependencias de Python y esté listo para recibir conexiones de switches.

---

## Fase 2: Switches Open vSwitch (SW1 y SW2)

Los switches Open vSwitch operan como conmutadores programables L2 mediante OpenFlow 1.3.

```bash
# 2.1 Construir imagen base de Open vSwitch
docker build -t lab-ovs:1.0.0 ./docker/ovs
```

* **¿Por qué se usa una imagen Alpine con Open vSwitch?** Es ligera (~50 MB) e incluye `ovsdb-server`, `ovs-vswitchd`, `tshark` y `python3` para la lógica de auto-detección de interfaces.

### 2.2 Switch 1 (lab-ovs-sw1) — Sector Clientes 1

```bash
docker run -d \
  --name lab-ovs-sw1 \
  --privileged \
  --network lab-oob \
  --ip 10.10.99.21 \
  -e OVS_DPID="0000000000000001" \
  -e OVS_CTRL_IP="10.10.99.10" \
  -e OVS_CTRL_PORT="6653" \
  -e OVS_PORTS="10.255.0.0/28=trunk:10,20,30,40,50 10.10.10.0/24=access:10 10.10.20.0/24=access:20" \
  --restart unless-stopped \
  lab-ovs:1.0.0
```

* **¿Por qué `--privileged`?** Open vSwitch necesita crear interfaces de red virtuales, sockets UNIX de base de datos (`/var/run/openvswitch/db.sock`) y manipular los módulos de puente del kernel.
* **¿Por qué `OVS_DPID="0000000000000001"`?** El Datapath ID (DPID) es el identificador único de 64 bits que el controlador SDN usa para reconocer a SW1 y enviarle sus flujos específicos.
* **¿Por qué `OVS_PORTS` con CIDR?** Docker asigna nombres de interfaces (`eth0`, `eth1`, etc.) en orden alfabético por nombre de red, no por orden de declaración. El entrypoint usa Python `ipaddress` para mapear cada interfaz a su rol según la subred asignada por Docker:
  * `10.255.0.0/28` -> Troncal con VLANs permitidas: 10, 20, 30, 40, 50.
  * `10.10.10.0/24` -> Puerto de acceso tagged internamente como VLAN 10.
  * `10.10.20.0/24` -> Puerto de acceso tagged internamente como VLAN 20.

```bash
# Conectar interfaces de datos a SW1
docker network connect lab-backbone lab-ovs-sw1
docker network connect lab-vlan10 lab-ovs-sw1
docker network connect lab-vlan20 lab-ovs-sw1
```

* **¿Por qué después del `run`?** Docker permite adjuntar múltiples redes a un contenedor en ejecución. Cada `network connect` genera una nueva interfaz virtual (`veth`) dentro del contenedor que el entrypoint de OVS agrega automáticamente al bridge `br0`.

### 2.3 Switch 2 (lab-ovs-sw2) — Sector Servidores y Clientes 2

```bash
docker run -d \
  --name lab-ovs-sw2 \
  --privileged \
  --network lab-oob \
  --ip 10.10.99.22 \
  -e OVS_DPID="0000000000000002" \
  -e OVS_CTRL_IP="10.10.99.10" \
  -e OVS_CTRL_PORT="6653" \
  -e OVS_PORTS="10.255.0.0/28=trunk:10,20,30,40,50 10.10.30.0/24=access:30 10.10.40.0/24=access:40 10.10.50.0/24=access:50" \
  --restart unless-stopped \
  lab-ovs:1.0.0

docker network connect lab-backbone lab-ovs-sw2
docker network connect lab-vlan30 lab-ovs-sw2
docker network connect lab-vlan40 lab-ovs-sw2
docker network connect lab-vlan50 lab-ovs-sw2
```

* **¿Por qué DPID 2?** Identifica al switch de servidores y áreas restantes ante el controlador Ryu.

```bash
# 2.4 Verificar estado de los switches y enlace con el controlador
docker exec lab-ovs-sw1 ovs-vsctl show
docker exec lab-ovs-sw2 ovs-vsctl show
```

* **¿Qué valida la salida?** Debe mostrar `is_connected: true` apuntando a `tcp:10.10.99.10:6653` y `fail_mode: secure` (si se pierde el controlador, no conmuta a modo switch tonto de aprendizaje).

---

## Fase 3: Firewall Router-on-a-Stick (lab-fw1)

El firewall actúa como la puerta de enlace predeterminada (Default Gateway) de todas las VLANs de clientes y servidores, aplicando las políticas de seguridad L3/L4 con `nftables` y reenviando peticiones DHCP mediante `dhcrelay`.

```bash
# 3.1 Construir imagen del Firewall
docker build -t lab-vpn:1.0.0 ./docker/vpn
```

```bash
# 3.2 Iniciar el Firewall
docker run -d \
  --name lab-fw1 \
  --cap-add=NET_ADMIN \
  --network lab-oob \
  --ip 10.10.99.1 \
  -e FW_TRUNK_NET="10.255.0.0/28" \
  -e FW_WAN_NET="192.0.2.0/24" \
  -e FW_VLANS="10:10.10.10.1/24 20:10.10.20.1/24 30:10.10.30.1/24 40:10.10.40.1/24 50:10.10.50.1/24" \
  --restart unless-stopped \
  lab-vpn:1.0.0

# Conectar al troncal backbone y a la red WAN
docker network connect lab-backbone lab-fw1
docker network connect lab-vlan30 lab-fw1
docker network connect lab-wan lab-fw1
```

* **¿Por qué `--cap-add=NET_ADMIN`?** El firewall no necesita `--privileged` completo; la capability `NET_ADMIN` le otorga los permisos justos para crear subinterfaces VLAN 802.1Q (`trunk0.10`, `trunk0.20`, etc.), habilitar `net.ipv4.ip_forward=1` y cargar tablas de `nftables`.
* **¿Por qué subinterfaces `trunk0.X`?** Es la técnica estándar de **Router-on-a-Stick**: una sola interfaz física/enlace troncal transporta múltiples VLANs etiquetadas. El firewall desencapsula la etiqueta 802.1Q y asigna la IP del gateway correspondiente (`10.10.X.1/24`).
* **¿Por qué `dhcrelay` dentro del entrypoint?** Los broadcasts DHCP (`255.255.255.255:67/udp`) no cruzan routers ni bridges aislados. `dhcrelay` escucha en `trunk0.10`, `trunk0.20`, `trunk0.40`, `trunk0.50` y reenvía las solicitudes como unicast a `10.10.30.10` (servidor Kea) insertando el campo `giaddr` con la IP del gateway de la VLAN de origen.

```bash
# 3.3 Verificar subinterfaces y reglas cargadas
docker exec lab-fw1 ip -4 addr show
docker exec lab-fw1 nft -s list ruleset
```

* **¿Qué valida?** Confirma que las subinterfaces `trunk0.10` a `trunk0.50` tienen sus IPs `.1/24` en estado `UP` y que la tabla `filter` tiene las reglas `counter accept` y `counter drop` configuradas.

---

## Fase 4: Servidores de Infraestructura y Aplicación (VLAN 30)

Todos los servidores corporativos se ubican en la red `lab-vlan30` (`10.10.30.0/24`).

### 4.1 Infraestructura Base (Kea DHCPv4 + BIND9 DNS en INFRA01)

```bash
# 4.1.1 Construir imagen con Kea, BIND9 y Supervisord
docker build -t lab-infra:1.0.0 ./docker/infra

# 4.1.2 Ejecutar INFRA01 con IP fija 10.10.30.10
docker run -d \
  --name lab-infra01 \
  --network lab-vlan30 \
  --ip 10.10.30.10 \
  --cap-add=NET_BIND_SERVICE \
  --cap-add=NET_RAW \
  --cap-add=NET_ADMIN \
  --restart unless-stopped \
  lab-infra:1.0.0
```

* **¿Por qué Kea y BIND9 juntos en un contenedor?** La especificación de Comercial Andina asigna la IP `10.10.30.10` tanto a DHCP como a DNS. En Docker, una IP pertenece a un contenedor; `supervisord` gestiona ambos daemons dentro del mismo espacio de red.
* **¿Por qué `--cap-add=NET_BIND_SERVICE,NET_RAW`?** BIND9 y Kea necesitan enlazar puertos privilegiados (<1024: UDP/TCP 53 y UDP 67) y capturar paquetes raw para procesar solicitudes DHCP.

### 4.2 Base de Datos PostgreSQL 16 (DB01)

```bash
# 4.2.1 Crear volumen persistente
docker volume create lab-db-data

# 4.2.2 Iniciar PostgreSQL con script de inicialización
docker run -d \
  --name lab-db01 \
  --network lab-vlan30 \
  --ip 10.10.30.30 \
  -e POSTGRES_DB=inventario \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=password_seguro_laboratorio \
  -v lab-db-data:/var/lib/postgresql/data \
  -v "$(pwd)/docker/db/init.sql:/docker-entrypoint-initdb.d/init.sql:ro" \
  --restart unless-stopped \
  postgres:16-alpine
```

* **¿Por qué `-v lab-db-data:...`?** Los datos de la base de datos `inventario` deben sobrevivir si el contenedor se reinicia o se actualiza.
* **¿Por qué `/docker-entrypoint-initdb.d/init.sql`?** Al inicializar la base de datos por primera vez, PostgreSQL ejecuta automáticamente este script, creando la tabla `items(id, name)` y el rol con privilegios mínimos `inventory_app`.

### 4.3 Backend API Flask (APP01)

```bash
# 4.3.1 Construir imagen del backend
docker build -t lab-app:1.0.0 ./docker/app

# 4.3.2 Iniciar la API
docker run -d \
  --name lab-web01-app \
  --network lab-vlan30 \
  --ip 10.10.30.21 \
  -e DB_HOST=10.10.30.30 \
  -e DB_NAME=inventario \
  -e DB_USER=inventory_app \
  -e DB_PASS=password_seguro_laboratorio \
  --restart unless-stopped \
  lab-app:1.0.0
```

* **¿Por qué variables de entorno separadas?** Permite que la app construya dinámicamente la cadena de conexión DSN (`postgresql://inventory_app:...@10.10.30.30:5432/inventario`) sin codificar credenciales en el código fuente.
* **¿Por qué escucha en `0.0.0.0:5000`?** Para que el reverse proxy Nginx (`10.10.30.20`) pueda reenviarle peticiones a través de la red `lab-vlan30`.

### 4.4 Frontend Nginx con TLS / Reverse Proxy (WEB01)

```bash
# 4.4.1 Construir imagen con certificados autofirmados y configuración
docker build -t lab-web:1.0.0 ./docker/web

# 4.4.2 Iniciar Nginx
docker run -d \
  --name lab-web01 \
  --network lab-vlan30 \
  --ip 10.10.30.20 \
  --restart unless-stopped \
  lab-web:1.0.0
```

* **¿Por qué OpenSSL en el Dockerfile?** Genera un certificado X.509 local con CN `intranet.andina.test`.
* **¿Por qué redirección 80 -> 443 en `nginx.conf`?** Garantiza que todo el tráfico viaje cifrado por HTTPS.
* **¿Por qué `proxy_pass http://10.10.30.21:5000/`?** Nginx actúa como punto único de entrada para los clientes, protegiendo al backend Flask de exposición directa.

### 4.5 Servidor de Archivos Samba (FILE01)

```bash
# 4.5.1 Construir imagen Samba
docker build -t lab-samba:1.0.0 ./docker/samba

# 4.5.2 Iniciar servicio SMB
docker run -d \
  --name lab-file01 \
  --network lab-vlan30 \
  --ip 10.10.30.40 \
  --cap-add=NET_ADMIN \
  --restart unless-stopped \
  lab-samba:1.0.0
```

* **¿Por qué `server min protocol = SMB2` en `smb.conf`?** Cumple con el requisito de seguridad de denegar explícitamente el protocolo obsoleto y vulnerable SMBv1 (NT1).
* **¿Por qué carpetas separadas?** Define los shares `administracion` (grupo `@adm`), `ventas` (grupo `@ventas`) y `comun` (lectura compartida).

---

## Fase 5: Clientes por Departamento (VLAN 10, 20, 40, 50)

Se despliegan contenedores Alpine ligeros que simulan las estaciones de trabajo de cada área.

```bash
# 5.1 Cliente Administración (VLAN 10)
docker run -d \
  --name lab-pc10a \
  --network lab-vlan10 \
  --ip 10.10.10.101 \
  --cap-add=NET_ADMIN \
  alpine:3.20 sh -c "ip route replace default via 10.10.10.1; sleep infinity"

# 5.2 Cliente Ventas (VLAN 20)
docker run -d \
  --name lab-pc20 \
  --network lab-vlan20 \
  --ip 10.10.20.102 \
  --cap-add=NET_ADMIN \
  alpine:3.20 sh -c "ip route replace default via 10.10.20.1; sleep infinity"

# 5.3 Cliente Invitados (VLAN 40)
docker run -d \
  --name lab-pc40 \
  --network lab-vlan40 \
  --ip 10.10.40.101 \
  --cap-add=NET_ADMIN \
  alpine:3.20 sh -c "ip route replace default via 10.10.40.1; sleep infinity"

# 5.4 Cliente Almacén (VLAN 50)
docker run -d \
  --name lab-pc50 \
  --network lab-vlan50 \
  --ip 10.10.50.101 \
  --cap-add=NET_ADMIN \
  alpine:3.20 sh -c "ip route replace default via 10.10.50.1; sleep infinity"
```

* **¿Por qué `ip route replace default via 10.10.X.1`?** Docker asigna por defecto el gateway del bridge local. Reemplazar la ruta por defecto hacia la subinterface del firewall (`.1`) fuerza a que todo el tráfico inter-VLAN viaje a través del router-on-a-stick y sea evaluado por las reglas de `nftables`.
* **¿Por qué `sleep infinity`?** Mantiene el contenedor en ejecución de fondo para poder ingresar vía `docker exec` a realizar pruebas de conectividad.

---

## Fase 6: Pila de Monitoreo y Observabilidad (VLAN 99 / OOB)

El stack de monitoreo reside en la red `lab-oob` (`10.10.99.0/24`) para no competir por ancho de banda con el tráfico de negocio.

```bash
# 6.1 Prometheus — Recolector de métricas en series de tiempo
docker run -d \
  --name lab-mon01-prom \
  --network lab-oob \
  --ip 10.10.99.30 \
  -v "$(pwd)/monitoring/prometheus.yml:/etc/prometheus/prometheus.yml:ro" \
  -v "$(pwd)/monitoring/alerts.yml:/etc/prometheus/alerts/alerts.yml:ro" \
  --restart unless-stopped \
  prom/prometheus:v2.53.0

# 6.2 Alertmanager — Gestor de estados de alerta
docker run -d \
  --name lab-mon01-amgr \
  --network lab-oob \
  --ip 10.10.99.31 \
  -v "$(pwd)/monitoring/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro" \
  --restart unless-stopped \
  prom/alertmanager:v0.27.0

# 6.3 Grafana — Visualización de tableros
docker run -d \
  --name lab-mon01-grafana \
  --network lab-oob \
  --ip 10.10.99.32 \
  -e GF_SECURITY_ADMIN_PASSWORD=admin_seguro_lab \
  --restart unless-stopped \
  grafana/grafana:10.4.2
```

* **¿Por qué volúmenes en modo `:ro` (read-only)?** Protege los archivos de configuración (`prometheus.yml`, `alerts.yml`) de escrituras accidentales por parte de los procesos de monitoreo.
* **¿Por qué `evaluation_interval: 15s`?** Permite detectar caídas de servicios (`TargetDown`) y evaluar reglas de alerta en ciclos cortos, adecuados para demostraciones de laboratorio.

---

## Fase 7: Verificación Integral del Sistema

Una vez levantada la infraestructura, se ejecutan los scripts de prueba que validan los contratos técnicos con evidencia directa.

```bash
export DB_PASS="password_seguro_laboratorio"

# 7.1 Validación de Switches, Trunks y Datapath IDs de OpenFlow
bash scripts/verify-stage4.sh
```
* **¿Qué prueba?** Valida que SW1 y SW2 estén conectados al controlador con DPID 1 y DPID 2, que el troncal transporte las VLANs 10, 20, 30, 40, 50 y que el aislamiento L2 funcione.

```bash
# 7.2 Validación de Gateways del Firewall y Enrutamiento Base
bash scripts/verify-stage5.sh
```
* **¿Qué prueba?** Confirma que las subinterfaces `10.10.10.1` a `10.10.50.1` respondan a ping desde sus respectivos clientes y que el tráfico inter-VLAN no autorizado sea descartado por default.

```bash
# 7.3 Validación de la Matriz de Seguridad nftables
bash scripts/verify-stage6.sh
```
* **¿Qué prueba?**
  * Acceso HTTPS permitido desde Administración (`pc10a`) a `10.10.30.20`.
  * Acceso bloqueado desde Invitados (`pc40`) hacia cualquier subred interna (`10.10.0.0/16`).
  * Acceso directo a la base de datos PostgreSQL (`5432`) denegado desde estaciones cliente.
  * Verificación de contadores (`counter packets > 0`) en las reglas activas.

```bash
# 7.4 Validación de Servicios Corporativos
bash scripts/verify-stage7.sh
```
* **¿Qué prueba?**
  * Resolución directa de `intranet.andina.test` -> `10.10.30.20` en BIND9.
  * Resolución inversa PTR de `10.10.30.30` -> `db.andina.test`.
  * Inserción y consulta persistente en PostgreSQL desde la aplicación Flask.
  * Acceso a recursos compartidos Samba con SMB2/3 y rechazo de conexiones SMB1.

---

## Equivalencia con Docker Compose

La ejecución manual comando por comando permite comprender cada parámetro de red, capability y volumen. Para despliegues automatizados y reproducibles, todo el conjunto de instrucciones anterior está encapsulado en el archivo declarativo:

```bash
export DB_PASS="password_seguro_laboratorio"
docker compose -f deploy/host/docker-compose.lab.yml up -d --build
```

Para desmontar y limpiar el laboratorio completo:

```bash
docker compose -f deploy/host/docker-compose.lab.yml down -v
```
