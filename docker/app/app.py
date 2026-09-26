import os
import re
from contextlib import contextmanager

from flask import Flask, jsonify, request

NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9 ._-]{0,119}$")
CONNECT_TIMEOUT_SECONDS = 5
STATEMENT_TIMEOUT = "5000ms"
SCHEMA = """CREATE TABLE IF NOT EXISTS items (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL
)"""


class ConfigurationError(RuntimeError):
    pass


def create_app(database_url=None, connect=None):
    app = Flask(__name__)
    app.config["DATABASE_URL"] = database_url or os.environ.get("DATABASE_URL")

    def get_connection():
        dsn = app.config["DATABASE_URL"]
        if not dsn:
            raise ConfigurationError("DATABASE_URL is required")
        if connect:
            return connect(dsn)
        import psycopg2
        return psycopg2.connect(dsn, connect_timeout=CONNECT_TIMEOUT_SECONDS)

    @contextmanager
    def database_cursor():
        connection = cursor = None
        try:
            connection = get_connection()
            cursor = connection.cursor()
            cursor.execute("SET statement_timeout = %s", (STATEMENT_TIMEOUT,))
            yield connection, cursor
        except Exception:
            if connection is not None:
                try:
                    connection.rollback()
                except Exception:
                    pass
            raise
        finally:
            if cursor is not None:
                try:
                    cursor.close()
                except Exception:
                    pass
            if connection is not None:
                try:
                    connection.close()
                except Exception:
                    pass

    @app.errorhandler(ConfigurationError)
    def missing_database_url(error):
        return jsonify(error=str(error)), 500

    @app.get("/healthz")
    def healthz():
        return jsonify(status="ok")

    @app.get("/readyz")
    def readyz():
        try:
            with database_cursor() as (_, cursor):
                cursor.execute("SELECT 1")
        except ConfigurationError:
            raise
        except Exception:
            return jsonify(status="not ready"), 503
        return jsonify(status="ready")

    @app.route("/items", methods=["GET", "POST"])
    def items():
        if request.method == "POST":
            payload = request.get_json(silent=True)
            if (not isinstance(payload, dict) or set(payload) != {"name"} or
                    not isinstance(payload["name"], str) or not NAME.fullmatch(payload["name"])):
                return jsonify(error="invalid request"), 400
            name = payload["name"]
            try:
                with database_cursor() as (connection, cursor):
                    cursor.execute("INSERT INTO items(name) VALUES (%s) RETURNING id", (name,))
                    item_id = cursor.fetchone()[0]
                    connection.commit()
            except ConfigurationError:
                raise
            except Exception:
                return jsonify(error="database unavailable"), 503
            return jsonify(id=item_id, name=name), 201
        try:
            with database_cursor() as (_, cursor):
                cursor.execute("SELECT id, name FROM items ORDER BY id")
                result = [dict(id=item_id, name=name) for item_id, name in cursor.fetchall()]
        except ConfigurationError:
            raise
        except Exception:
            return jsonify(error="database unavailable"), 503
        return jsonify(result)

    @app.cli.command("init-db")
    def init_db():
        """Create the inventory schema; run explicitly during deployment."""
        with database_cursor() as (connection, cursor):
            cursor.execute(SCHEMA)
            connection.commit()

    return app


app = create_app()

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000)
