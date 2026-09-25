#!/usr/bin/env python3
# Fase 2/3: crear proyecto GNS3 y nodos base usando la API 2.2.55
# Fuente de verdad: config/lab.yaml
import json, sys, yaml, urllib.request

GNS3 = "http://127.0.0.1:3080/v2"

def req(method, path, payload=None):
    data = None if payload is None else json.dumps(payload).encode()
    r = urllib.request.Request(GNS3 + path, data=data, method=method,
                               headers={"Content-Type":"application/json"})
    with urllib.request.urlopen(r) as resp:
        body = resp.read().decode() or "{}"
        return resp.status, json.loads(body if body.strip() else "{}")

def main():
    with open("config/lab.yaml") as f:
        lab = yaml.safe_load(f)
    name = lab["meta"]["project_name"]
    st, body = req("POST", "/projects", {"name": name})
    if st == 201:
        pid = body["project_id"]
    else:
        _, projects = req("GET", "/projects")
        pid = next(p["project_id"] for p in projects if p["name"] == name)
    req("POST", f"/projects/{pid}/open")
    print(f"[+] Proyecto '{name}' listo ({pid}) — nodos y enlaces se agregan en fases posteriores.")

if __name__ == "__main__":
    sys.exit(main())
