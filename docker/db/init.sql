-- init.sql — esquema inventario para APP01
CREATE TABLE IF NOT EXISTS items (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'inventory_app') THEN
    CREATE ROLE inventory_app LOGIN PASSWORD 'inventory_app_secret';
  END IF;
END
$$;

GRANT CONNECT ON DATABASE inventario TO inventory_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON items TO inventory_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO inventory_app;
