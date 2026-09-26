import os
import pathlib
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(pathlib.Path(__file__).parents[1] / "docker" / "app"))
from app import create_app


class FakeCursor:
    def __init__(self, fail_query=None):
        self.rows, self.next_id, self.fail_query = [], 1, fail_query
        self.closed, self.queries = False, []

    def execute(self, query, params=None):
        self.queries.append((query, params))
        if self.fail_query and query.startswith(self.fail_query):
            raise RuntimeError("database error")
        if query.startswith("INSERT"):
            self.rows.append((self.next_id, params[0]))
            self.last, self.next_id = (self.next_id,), self.next_id + 1

    def fetchone(self): return getattr(self, "last", (1,))
    def fetchall(self): return self.rows
    def close(self): self.closed = True


class FakeConnection:
    def __init__(self, fail_query=None):
        self.cursor_instance, self.committed = FakeCursor(fail_query), False
        self.closed, self.rolled_back = False, False

    def cursor(self): return self.cursor_instance
    def commit(self): self.committed = True
    def rollback(self): self.rolled_back = True
    def close(self): self.closed = True


class InventoryAppTests(unittest.TestCase):
    def setUp(self):
        self.connection = FakeConnection()
        self.client = create_app("postgresql://test", lambda _: self.connection).test_client()

    def test_post_then_get_items_in_id_order(self):
        created = self.client.post("/items", json={"name": "router-1"})
        self.assertEqual(created.status_code, 201)
        self.assertEqual(created.get_json(), {"id": 1, "name": "router-1"})
        self.assertEqual(self.client.get("/items").get_json(), [{"id": 1, "name": "router-1"}])

    def test_post_rejects_invalid_json_names_and_fields(self):
        for kwargs in ({}, {"json": {"name": "router", "extra": True}},
                       {"json": {"name": " bad"}}, {"json": {"name": "x" * 121}}):
            response = self.client.post("/items", **kwargs)
            self.assertEqual(response.status_code, 400)
            self.assertEqual(response.get_json(), {"error": "invalid request"})

    def test_readyz_checks_database_and_reports_unavailable(self):
        self.assertEqual(self.client.get("/readyz").get_json(), {"status": "ready"})
        app = create_app("postgresql://test", lambda _: (_ for _ in ()).throw(Exception()))
        response = app.test_client().get("/readyz")
        self.assertEqual((response.status_code, response.get_json()), (503, {"status": "not ready"}))

    def test_database_operations_set_bounded_timeouts_and_close_resources(self):
        connection = FakeConnection()
        with patch("psycopg2.connect", return_value=connection) as db_connect:
            response = create_app("postgresql://test").test_client().get("/readyz")

        self.assertEqual((response.status_code, response.get_json()), (200, {"status": "ready"}))
        db_connect.assert_called_once_with("postgresql://test", connect_timeout=5)
        self.assertIn(("SET statement_timeout = %s", ("5000ms",)),
                      connection.cursor_instance.queries)
        self.assertTrue(connection.cursor_instance.closed)
        self.assertTrue(connection.closed)

    def test_failed_write_rolls_back_and_closes_resources(self):
        connection = FakeConnection(fail_query="INSERT")
        client = create_app("postgresql://test", lambda _: connection).test_client()

        response = client.post("/items", json={"name": "router-1"})

        self.assertEqual((response.status_code, response.get_json()),
                         (503, {"error": "database unavailable"}))
        self.assertTrue(connection.rolled_back)
        self.assertTrue(connection.cursor_instance.closed)
        self.assertTrue(connection.closed)

    def test_database_url_is_required(self):
        with patch.dict(os.environ, {"DATABASE_URL": ""}):
            response = create_app(connect=lambda _: self.connection).test_client().get("/readyz")
        self.assertEqual((response.status_code, response.get_json()),
                         (500, {"error": "DATABASE_URL is required"}))

    @unittest.skipUnless(os.environ.get("DATABASE_URL"), "DATABASE_URL not set")
    def test_opt_in_database_readiness(self):
        response = create_app().test_client().get("/readyz")
        self.assertEqual((response.status_code, response.get_json()), (200, {"status": "ready"}))


if __name__ == "__main__":
    unittest.main()
