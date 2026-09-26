FROM alpine:3.20

RUN apk add --no-cache openvswitch bash iproute2 iputils tshark \
 && mkdir -p /var/run/openvswitch

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 6653 6633

ENTRYPOINT ["/entrypoint.sh"]
