# Preflight / Diagnóstico del entorno

- Fecha UTC: 2026-09-25 23:20:10 Z
- Hostname: codespaces-65b4a1
- Usuario: vscode

## 1. Captación de Infraestructura Base
```
Linux codespaces-65b4a1 6.8.0-1064-azure #72~22.04.1-Ubuntu SMP Wed Jul 22 23:39:45 UTC 2026 x86_64 x86_64 x86_64 GNU/Linux
PRETTY_NAME="Ubuntu 22.04.5 LTS"
NAME="Ubuntu"
VERSION_ID="22.04"
VERSION="22.04.5 LTS (Jammy Jellyfish)"
VERSION_CODENAME=jammy
```

## 2. Hardware y Capacidad
```
4
               total        used        free      shared  buff/cache   available
Mem:            15Gi       847Mi       5.1Gi        60Mi       9.7Gi        14Gi
Swap:             0B          0B          0B
Filesystem      Size  Used Avail Use% Mounted on
/dev/loop4       32G  1.2G   29G   4% /workspaces
```

## 3. Herramientas base instaladas
```
[OK]  git -> /usr/local/bin/git
[OK]  curl -> /usr/bin/curl
[OK]  wget -> /usr/bin/wget
[OK]  jq -> /usr/bin/jq
[OK]  python3 -> /usr/bin/python3
[OK]  pip3 -> /usr/bin/pip3
[MISS] docker
[MISS] docker-compose
[MISS] openvpn
[MISS] samba
[MISS] openvswitch-vswitchd
[MISS] ovs-vsctl
[MISS] ovs-ofctl
[MISS] ryu-manager
```

## 4. Docker daemon / estado
```
Docker no disponible o no configurado
```

## 5. GNS3 Server
```
2.2.55
vscode       126  2.4  0.3 210224 51868 ?        S    23:19   0:00 /usr/share/gns3/gns3-server/bin/python /usr/bin/gns3server --config /home/vscode/.config/GNS3/2.2/gns3_server.conf
---gns3_server.conf---
[Server]
host = 0.0.0.0
port = 3080
allow_remote_console = True
console_start_port_range = 5000
console_end_port_range = 5050
vnc_console_start_port_range = 5900
vnc_console_end_port_range = 5950
images_path = /home/vscode/GNS3/images
projects_path = /home/vscode/GNS3/projects
appliances_path = /home/vscode/GNS3/appliances
report_errors = False
auto_start = True
daemon = True
pid = /tmp/gns3server.pid
log = /tmp/gns3server.log

[Dynamips]
allocate_aux_console_ports = False
mmap_support = True
nodiskfilter = False
ghost_ios_support = True
sparse_memory_support = True
dynamips_path = /usr/bin/dynamips

[Qemu]
enable_kvm = False
require_kvm = False
qemu_path = /usr/bin/qemu-system-x86_64

[VPCS]
vpcs_path = /usr/bin/vpcs

[Ubridge]
ubridge_path = /usr/bin/ubridge
```

## 6. Red y Puertos Activos
```
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    inet 10.0.0.218/16 metric 100 brd 10.0.255.255 scope global eth0
3: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default 
    inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0
LISTEN 0      100          0.0.0.0:3080       0.0.0.0:*    users:(("gns3server",pid=126,fd=13))
LISTEN 0      128          0.0.0.0:2222       0.0.0.0:*                                        
LISTEN 0      4096   127.0.0.53%lo:53         0.0.0.0:*                                        
LISTEN 0      128             [::]:2222          [::]:*                                        
```

## 7. Generando evidencia cruda

## 8. Conclusión
> Diagnóstico automatizado completado. Ver docs/estado.md para estado global.
