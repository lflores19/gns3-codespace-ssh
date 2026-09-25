FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    openvswitch-switch tcpdump dnsutils jq python3-pip postgresql-client \
    && pip3 install --no-cache-dir ryu gns3fy pyyaml \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# GNS3 Server (kept in repo config)
COPY .devcontainer/gns3_server.conf /tmp/gns3_server.conf
COPY .devcontainer/start-daemon.sh /usr/local/bin/start-lab-daemon.sh
RUN chmod +x /usr/local/bin/start-lab-daemon.sh
