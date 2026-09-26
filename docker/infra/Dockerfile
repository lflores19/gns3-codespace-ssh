FROM alpine:3.20
RUN apk add --no-cache kea bind iputils supervisor && mkdir -p /var/bind/zones /var/log/supervisor
COPY named.conf /etc/bind/named.conf
COPY zones/ /var/bind/zones/
COPY kea-dhcp4.conf /etc/kea/kea-dhcp4.conf
COPY supervisord.conf /etc/supervisord.conf
EXPOSE 53/udp 53/tcp 67/udp
ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
