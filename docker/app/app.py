import os, psycopg2
from flask import Flask, request, jsonify
app = Flask(__name__)
DSN = os.environ.get("DATABASE_URL", "host=db1 dbname=inventario user=postgres password=changeme")
def conn(): return psycopg2.connect(DSN)
@app.route("/healthz")
def healthz(): return {"status": "ok"}
@app.route("/items", methods=["GET","POST"])
def items():
    c = conn(); cur = c.cursor()
    cur.execute("CREATE TABLE IF NOT EXISTS items(id serial primary key, name text not null)")
    if request.method == "POST":
        name = (request.json or {}).get("name","item")
        cur.execute("INSERT INTO items(name) VALUES (%s) RETURNING id", (name,))
        iid = cur.fetchone()[0]; c.commit()
        return jsonify(id=iid, name=name), 201
    cur.execute("SELECT id,name FROM items ORDER BY id")
    return jsonify([{"id":i,"name":n} for i,n in cur.fetchall()])
