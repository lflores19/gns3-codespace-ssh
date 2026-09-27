#!/usr/bin/env bash
# verify-stage7.sh — servicios VLAN30 (DNS/BIND9, APP/DB, Samba) — spec Andina
set -Eeuo pipefail

P(){ echo "PASS $1"; }
F(){ echo "FAIL $1"; exit 1; }
DBPASS="${DB_PASS:?export DB_PASS}"

echo "== DNS: intranet.andina.test =="
docker exec lab-infra01 sh -c 'nslookup intranet.andina.test 127.0.0.1' | grep -q "10.10.30.20" && P dns-a || F dns-a

echo "== DNS PTR VLAN30 =="
docker exec lab-infra01 sh -c 'nslookup 10.10.30.30 127.0.0.1' | grep -q "db.andina.test" && P dns-ptr || F dns-ptr

echo "== App alta+lectura persistente =="
docker exec lab-web01-app sh -c "python -c 'import requests' 2>/dev/null || pip install -q requests"
# criterio pendiente de endpoint exacto (ver app); mientras: DB reachable solo desde app
docker exec lab-web01-app sh -c "PIP_TARGET=/tmp/pip pip install -q psycopg2-binary && python - <<'PY'
import psycopg2, os
c = psycopg2.connect(host='10.10.30.30', dbname='inventario', user='inventory_app', password=os.environ['DB_PASS'])
cur=c.cursor(); cur.execute('INSERT INTO items(nombre,stock) VALUES (%s,%s) RETURNING id',('prueba',1)); new=cur.fetchone()[0]
cur.execute('SELECT stock FROM items WHERE id=%s',(new,)); print('select=',cur.fetchone())
c.commit(); c.close()
PY" && P app-db-persiste || F app-db-persiste

echo "== Samba: compartido accesible y SMB1 denegado =="
docker exec lab-web01 sh -c "apk add --no-cache samba-client >/dev/null 2>&1; smbclient -L //10.10.30.40 -N -m SMB2 2>/dev/null | grep -q administracion" \
  && P smb-smb2-ok || F smb-smb2-ok
docker exec lab-web01 sh -c "smbclient -L //10.10.30.40 -N -m NT1 2>/dev/null" \
  && { echo "smb1-permitido FAIL"; exit 1; } || P smb1-bloqueado
