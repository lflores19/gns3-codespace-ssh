# Arquitectura General: Sistema Andina (Caso de Estudio)

> **Contexto**: Se presenta la arquitectura de dos entornos convivientes y complementarios. 
> 
> - **Entorno A**: Matriz de laboratorio implementada y validada históricamente en la nube (Codespaces - Actualmente apagada).
> - **Entorno B**: Plano Dockerizado local para contenedores (Diseñado siguiendo las especificaciones B2B "Comercial Andina").
>
> Esta diagramación ilustra el diseño lógico, direccionamiento, conexiones de control y flujos de datos en ambas piezas sin necesitar infraestructura operativa subyacente.

---

## Arquitectura Maestra Unificada (Comercial Andina — Plano Docker B)

```mermaid
graph TD
    %% Definición de estilos
    classDef cloud fill:#f8f9fa,stroke:#ced4da,stroke-dasharray: 5 5;
    classDef ctrl fill:#cfe2ff,stroke:#0d6efd,stroke-width:2px;
    classDef sw fill:#d1e7dd,stroke:#198754,stroke-width:2px;
    classDef fw fill:#f8d7da,stroke:#dc3545,stroke-width:2px;
    classDef srv fill:#fff3cd,stroke:#ffc107,stroke-width:2px;
    classDef cli fill:#e2e3e5,stroke:#6c757d,stroke-width:2px;

    %% Internet Cloud
    WAN_Cloud(("HTML / Cloud (Monitoreo Externo)")):::cloud

    subgraph SG_INFRA["Plataforma Local Linux + Docker"]
        
        subgraph SG_MGMT["Red: Gestión / Control (OOB VLAN 99)"]
            direction TB
            RYU["Ryu Controller (lab-ctrl1)<br/>IP: 10.10.99.10<br/>Ryu OpenFlow"]:::ctrl
            PROM["Prometheus (lab-mon01-prom)<br/>IP: 10.10.99.30"]:::srv
            AM["Alertmanager (lab-mon01-amgr)<br/>IP: 10.10.99.31"]:::srv
            GRAF["Grafana (lab-mon01-grafana)<br/>IP: 10.10.99.32"]:::srv
        end

        subgraph SG_PLANB["Plano de Datos (Open VSwitch)"]
            FW1["Firewall Gateway (lab-fw1)<br/>nftables + dhcrelay<br/>Eth0.10 a .50 - Gateways .1"]:::fw
            
            subgraph SG_OVS["Switches SDN"]
                SW1["OVS SW 1 (lab-ovs-sw1)<br/>Mgmt IP: 10.10.99.21<br/>DPID: 1"]:::sw
                SW2["OVS SW 2 (lab-ovs-sw2)<br/>Mgmt IP: 10.10.99.22<br/>DPID: 2"]:::sw
            end
            
            SW1 ---|Trunk Tagged VLAN 10,20,30,40,50<br/>Bridge Local (10.255.0.0/28)| SW2
            FW1 ---|Trunk Tagged VLAN 10,20,30,40,50| SW1
            FW1 ---|Trunk Tagged VLAN 30| SW2
        end

        subgraph SG_ADM["OVS1 Access - VLAN 10 [10.10.10.0/24]"]
            PC10["CA-ADM01 Cliente Adm<br/>(lab-pc10a)<br/>IP: 10.10.10.101"]:::cli
        end

        subgraph SG_VENT["OVS1 Access - VLAN 20 [10.10.20.0/24]"]
            PC20["CA-VTA01 Cliente Ventas<br/>(lab-pc20)<br/>IP: 10.10.20.102"]:::cli
        end

        subgraph SG_SRV["OVS2 Access - VLAN 30 [10.10.30.0/24] (Servidores)"]
            INFRA["KEA/BIND9 (lab-infra01)<br/>IP: 10.10.30.10<br/>DNS / DHCP Relay Target"]:::srv
            WEB["Nginx (lab-web01)<br/>IP: 10.10.30.20<br/>HTTPS https://intranet.andina.test"]:::srv
            APP["Flask (lab-web01-app)<br/>IP: 10.10.30.21<br/>:5000 Implementation"]:::srv
            DB["Postgres (lab-db01)<br/>IP: 10.10.30.30<br/>:5432 Inventory"]:::srv
            SMB["Samba (lab-file01)<br/>IP: 10.10.30.40<br/>Shares B2B cliente corp"]:::srv
        end

        subgraph SG_WARE["OVS2 Access - VLAN 50 [10.10.50.0/24] (Almacén)"]
            PC50["CA-ALM01 Cliente Almacén<br/>(lab-pc50)<br/>IP: 10.10.50.101"]:::cli
        end

        subgraph SG_GUESS["OVS2 Access - VLAN 40 [10.10.40.0/24]"]
            PC40["Invitados (lab-pc40)<br/>IP: 10.10.40.101"]:::cli
        end
    end

    %% Flujos y Conexiones Ethernet (Capa Física / Docker Bridges)
    SW1 -->|eth_access:10| PC10
    SW1 -->|eth_access:20| PC20
    
    SW2 -->|eth_access:30| INFRA
    SW2 -->|eth_access:30| WEB
    SW2 -->|eth_access:30| APP
    SW2 -->|eth_access:30| DB
    SW2 -->|eth_access:30| SMB

    SW2 -->|eth_access:50| PC50
    SW2 -->|eth_access:40| PC40

    %% Flujo Lógico dentro de VLAN30
    WEB -->|"REST /api/ - Proxy"| APP
    APP -->|"SOCKET DB"| DB

    %% Plano Control y Monitoreo Fuera de banda
    SW1 -.->|"OpenFlow 13 (TCP 6653)"| RYU
    SW2 -.->|"OpenFlow 13 (TCP 6653)"| RYU
    
    PROM -.->|"scraping node_exporter"| SW1
    PROM -.->|"scraping configs"| WEB
    PROM -.-> AM
    GRAF -.-> PROM
    
    AM -.->|"Gateway WAN Outbound"| WAN_Cloud
    PC40 -.->|"NAT / Allowed Traffic Only"| FW1
    FW1 -.->|"Traffic Outbound"| WAN_Cloud
```

## Tabla de Resumen de Elementos (Andina Model)

| Dominio | Elemento | Contenedor | Ip Mgmt / Endpoint | Función Estratégica |
|---|---|---|---|---|
| **Plan datos** | `lab-ovs-sw1` | `docker/ovs` | `10.10.99.21` (OOB) | Core de clientes |
| **Plan datos** | `lab-ovs-sw2` | `docker/ovs` | `10.10.99.22` (OOB) | Core de servidores |
| **Borde Ruta** | `lab-fw1` | `docker/vpn` | `10.10.10.1` etc | Políticas L3 y NAT |
| **Control** | `lab-ctrl1` | `controller` | `10.10.99.10` (OOB) | Flujos OF 1.3 |
| **Corporativa** | `lab-infra01` | `docker/infra` | `10.10.30.10` | NTP / DHCP / DNS |
| **Corporativa** | `lab-web01` | `docker/web` | `10.10.30.20` | UI e intranet HTTPS |
| **Corporativa** | `lab-web01-app` | `docker/app` | `10.10.30.21` | Processing flask |
| **Calidad DBs** | `lab-db01` | `postgres:16-alpine` | `10.10.30.30` | Persistencia inventario |
| **Corporativa** | `lab-file01` | `docker/samba` | `10.10.30.40` | Documentos (SMB 3) |

---

## Reglas Ruteo y Seguridad (Intent L3)

Basado en `docker/vpn/fw.nft`:

1. **Administración, Ventas y Almacén**:
   - DNS/DHCP -> Infra (`10.10.30.10`).
   - HTTPS -> Web (`10.10.30.20`).
   - SMB -> Filesystem (`10.10.30.40`).
2. **Invitados**: 
   - Solo ruta al Gateway y Salida a Internet. Por seguridad totalmente negada a subredes internas (`guest-block-interno`).
3. **Interconectividad BD**: 
   - Único origen permitido a puerto `5432` son `10.10.30.20` y `10.10.30.21`. El resto se descarta con Firewall rules counters.

---

## Ecología Máquina Base (Stubs de Arquitectura Codespaces vs Hierarchical Runtimes)

El Codespace anterior correáis nodos QEMU propios (`utp-network-lab`). Este diagrama corresponde a la evolución estructural en su interface local (`bash scripts/bootstrap-images.sh`).

Los estado del arte de estos controladores y switches (Comercial Andina) vienen en las dependencias:

- **`scripts/preflight-host.sh`** (análisis de hardware).
- **`scripts/export-lab.sh` (e import)** para portabilidad del esquema de verificación original con `gns3server` histórico.
