FROM alpine:3.20
RUN apk add --no-cache bind iputils && mkdir -p /var/bind/zones
COPY named.conf /etc/bind/named.conf
COPY zones/ /var/bind/zones/
EXPOSE 53/udp 53/tcp
ENTRYPOINT ["named", "-g", "-c", "/etc/bind/named.conf"]
