FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

LABEL purpose="GNS3 daemon lab with nested Docker + OVS (privileged codespace)"

ARG DEBIAN_FRONTEND=noninteractive

# --- Runtime networking + orchestration stack ---
RUN apt-get update && apt-get install -y --no-install-recommends \
    docker.io iptables iproute2 iputils-ping dnsutils \
    openvswitch-switch tcpdump \
    python3 python3-pip python3-venv \
    postgresql-client jq && \
    pip3 install --no-cache-dir ryu gns3fy pyyaml && \
    rm -rf /var/lib/apt/lists/*

# vscode user goes to docker group (daemon runs as root via helper script)
RUN usermod -aG docker vscode && \
    mkdir -p /home/vscode/GNS3/{images/IOS,images/QEMU,projects,appliances} && \
    chown -R vscode:vscode /home/vscode/GNS3

# GNS3 Server 2.2.x (aligned with desktop GUI 2.2.55)
RUN pip3 install --no-cache-dir "gns3-server==2.2.55" "gns3-gui==2.2.55" && \
    apt-get update && apt-get install -y --no-install-recommends \
    dynamips vpcs ubridge qemu-system-x86 qemu-utils telnet && \
    rm -rf /var/lib/apt/lists/* && \\
    setcap 'cap_net_admin,cap_net_raw=ep' /usr/bin/ubridge 2>/dev/null || true

# Entrypoint helper: start dockerd + ovsdb/vswitchd as root at container start
COPY start-daemon.sh /usr/local/bin/start-lab-daemon.sh
RUN chmod +x /usr/local/bin/start-lab-daemon.sh
