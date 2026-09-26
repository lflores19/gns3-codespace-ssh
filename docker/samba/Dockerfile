FROM alpine:3.20
RUN apk add --no-cache samba samba-common-tools && mkdir -p /srv/shares/{administracion,ventas,comun}
COPY smb.conf /etc/samba/smb.conf
EXPOSE 445
ENTRYPOINT ["smbd", "-F", "--no-process-group", "-s", "/etc/samba/smb.conf"]
