FROM nginx:1.27-alpine
RUN sed -ri 's|listen\s+80;|listen 8080;|' /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/index.html
