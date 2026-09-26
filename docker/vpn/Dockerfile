FROM alpine:3.20

RUN apk add --no-cache nftables iproute2 iputils openvpn bash gettext \
 && mkdir -p /etc/firewall

COPY entrypoint-fw.sh /entrypoint-fw.sh
COPY fw.nft /etc/firewall/fw.nft
RUN chmod +x /entrypoint-fw.sh

ENTRYPOINT ["/entrypoint-fw.sh"]
