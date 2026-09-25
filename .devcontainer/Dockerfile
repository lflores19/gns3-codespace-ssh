FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

ENV DEBIAN_FRONTEND=noninteractive

# Update system and install required system tools, SSH and GNS3 dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    ca-certificates \
    curl \
    wget \
    gnupg \
    openssh-server \
    sudo \
    iproute2 \
    iptables \
    net-tools \
    telnet \
    tcpdump \
    bridge-utils \
    qemu-system-x86 \
    qemu-utils \
    python3 \
    python3-pip \
    python3-dev \
    python3-setuptools \
    gcc \
    libcap2-bin \
    git \
    nano \
    vim \
    procps \
    && add-apt-repository -y ppa:gns3/ppa \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       dynamips \
       ubridge \
       vpcs \
       gns3-server \
       || pip3 install --no-cache-dir gns3-server \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Grant network capabilities to ubridge and dynamips
RUN if [ -f /usr/bin/ubridge ]; then setcap cap_net_admin,cap_net_raw=ep /usr/bin/ubridge; fi && \
    if [ -f /usr/bin/dynamips ]; then setcap cap_net_admin,cap_net_raw=ep /usr/bin/dynamips; fi

# Configure SSH daemon port & permissions for vscode user
RUN mkdir -p /var/run/sshd && \
    sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config 2>/dev/null || true && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config 2>/dev/null || true && \
    echo "vscode ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Create workspace and configuration paths
RUN mkdir -p /home/vscode/.config/GNS3/2.2 \
             /home/vscode/GNS3/projects \
             /home/vscode/GNS3/images/QEMU \
             /home/vscode/GNS3/images/IOS \
             /home/vscode/GNS3/appliances && \
    chown -R vscode:vscode /home/vscode/.config /home/vscode/GNS3

USER vscode
