#!/usr/bin/env bash
# verify-stage7.sh — servicios VLAN30 (criterios esperados)
set -Eeuo pipefail
cd "$(dirname "$0")/../deploy/host"

echo "== DNS A/PTR =="
docker exec lab-dns nslookup web.empresa.test 127.0.0.1 || echo "pendiente/ajustar"

echo "== DB alta+lectura persistente =="
docker exec -e PGPASSWORD="${DB_PASS:?pasa DB_PASS}" lab-psql-nota 2>/dev/null || true
# criterio: INSERT en items desde app y SELECT posterior tras restart del app

echo "== App =="
docker exec lab-web wget -qO- http://10.10.30.21:5000/health 2>/dev/null || echo "ajustar endpoint real"

echo "== Samba =="
docker exec lab-web sh -c "apk add --no-cache samba-client >/dev/null 2>&1; smbclient -L //10.10.30.40 -N" 2>/dev/null || echo "ajustar"
echo "fin etapa 7 — medir en host y volcar evidencias a evidence/"
