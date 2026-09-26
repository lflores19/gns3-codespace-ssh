# APP01 / DB01 inventory verification

This runbook records operational checks for the deployed lab topology; it does not deploy to or modify a Codespace. The observed deployment is Flask/Gunicorn on `client1` (`172.16.0.21:5000`) and PostgreSQL 16 on `mon1` (`172.16.0.30:5432`), co-located with monitoring. `DATABASE_URL` is required and must come from the process environment or an approved secret manager. Never version a URL or password.

## Alpine QEMU prerequisites

Install client-side verification tools only:

```sh
apk add --no-cache curl postgresql16-client
```

For local tests (not required on QEMU), create a venv and install the declared dependencies:

```sh
python3 -m venv .venv && . .venv/bin/activate
pip install -r docker/app/requirements.txt
python3 -m unittest tests/test_inventory_app.py
```

The unit suite uses a fake connection. Its database readiness test runs only when `DATABASE_URL` is set.

## APP01 bootstrap and API checks

Supply the database URL by your secret-handling mechanism (the following is a placeholder):

```sh
export DATABASE_URL='postgresql://USER:PASSWORD@DB_HOST:5432/inventario'
cd docker/app
flask --app app init-db
gunicorn --bind 0.0.0.0:5000 app:app
```

Gunicorn is the production WSGI entry point. `python app.py` is a loopback-only development smoke check; do not expose it or use it for lab service operation.

From another host, replace `APP_HOST`:

```sh
curl -fsS http://APP_HOST:5000/healthz
curl -fsS http://APP_HOST:5000/readyz
curl -i -H 'Content-Type: application/json' -d '{"name":"router-1"}' http://APP_HOST:5000/items
curl -fsS http://APP_HOST:5000/items
curl -i -H 'Content-Type: application/json' -d '{"name":" bad"}' http://APP_HOST:5000/items
```

Expected: health `{"status":"ok"}`, readiness `{"status":"ready"}`, POST `201` with an ID, ID-ordered GET, and invalid POST `400`. Connections time out after five seconds and each statement after five seconds. Only `init-db` creates schema; requests run no DDL.

## DB01 authentication, source restriction, and persistence

Positive authentication (do not echo the secret):

```sh
psql "$DATABASE_URL" -c 'SELECT 1'
```

For the negative check, set an intentionally wrong password only in the current terminal, require nonzero exit, then remove it:

```sh
export BAD_DATABASE_URL='postgresql://USER:wrong-password@DB_HOST:5432/inventario'
psql "$BAD_DATABASE_URL" -c 'SELECT 1'; test $? -ne 0
unset BAD_DATABASE_URL
```

To prove restart persistence, record the POST response ID, stop/start PostgreSQL on `mon1`, then stop/start the application on `client1` using the normal GNS3 procedure. Repeat `GET /items` and `/readyz`; the ID and name must remain. The observed run is recorded in `evidence/APP01-crud.txt`.

## Operational notes and limits

- `inventory_app` is a persistent SCRAM role. The observed `pg_hba.conf` permits only `172.16.0.21/32` for `inventario` and rejects other IPv4/IPv6 hosts; positive, rejected-source, and invalid-password checks are in `evidence/DB01-isolation.txt`.
- HBA is a PostgreSQL L3 source check on the shared DMZ L2 VLAN, not firewall isolation. It does not mitigate source-IP spoofing or a compromised `client1`.
- Keep credentials and the three private qcow2 backups outside this repository. Do not log URLs, passwords, hashes, or backup locations.
