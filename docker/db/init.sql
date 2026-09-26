-- init.sql — esquema mínimo inventario (mismo contrato DB del Codespace: APP01)
CREATE TABLE IF NOT EXISTS items (
  id SERIAL PRIMARY KEY,
  nombre TEXT NOT NULL,
  stock INT DEFAULT 0
);

CREATE ROLE inventory_app LOGIN PASSWORD 'CHANGEME_LAB_ONLY';
GRANT CONNECT ON DATABASE inventario TO inventory_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON items TO inventory_app;
