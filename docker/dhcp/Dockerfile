FROM alpine:3.20
RUN apk add --no-cache kea iproute2
COPY kea-dhcp4.conf /etc/kea/kea-dhcp4.conf
EXPOSE 67/udp
ENTRYPOINT ["kea-dhcp4", "-c", "/etc/kea/kea-dhcp4.conf"]
