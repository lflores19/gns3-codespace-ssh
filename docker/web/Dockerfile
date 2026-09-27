FROM nginx:1.27-alpine
RUN apk add --no-cache openssl \
    && mkdir -p /etc/nginx/ssl \
    && openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
       -subj "/C=PE/ST=Lima/L=Lima/O=Comercial Andina/CN=intranet.andina.test" \
       -keyout /etc/nginx/ssl/key.pem -out /etc/nginx/ssl/cert.pem
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 80 443
