#!/usr/bin/env bash
set -x
sudo docker build -q -t lab-web:nginx docker/web
sudo docker build -q -t lab-app:flask docker/app
sudo docker build -q -t lab-controller:ryu controller
sudo docker pull -q postgres:16-alpine
sudo docker rm -f lab-web1 lab-app1 lab-db1 lab-ctrl1 2>/dev/null
sudo docker run -d --restart unless-stopped --name lab-web1 --network host lab-web:nginx
sudo docker run -d --restart unless-stopped --name lab-db1 --network host \
  -e POSTGRES_PASSWORD=changeme -e POSTGRES_DB=inventario \
  -v lab-dbdata:/var/lib/postgresql/data postgres:16-alpine -p 5433
sleep 8
sudo docker run -d --restart unless-stopped --name lab-app1 --network host \
  -e DATABASE_URL="host=127.0.0.1 port=5433 dbname=inventario user=postgres password=changeme" lab-app:flask
sudo docker run -d --restart unless-stopped --name lab-ctrl1 --network host lab-controller:ryu
sudo docker ps
echo RUN_DONE
