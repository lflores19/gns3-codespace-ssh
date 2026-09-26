#!/usr/bin/env python3
"""Capture a bounded, API-driven OPS01 restart comparison without guest writes."""
import argparse
import json
import re
import telnetlib
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

PROJECT_ID = "e792c7b3-8a50-4d0b-a93a-ab64e7e6e344"
DEFAULT_API = "http://127.0.0.1:3080"
DEFAULT_PASSWORD_FILE = "/home/vscode/.config/gns3-lab/poc-root-password"
NODES = ("web1", "admin-vm")


class VerificationError(RuntimeError):
    pass


def api_request(api, path, method="GET"):
    request = urllib.request.Request(f"{api}{path}", method=method)
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            return response.status, response.read()
    except urllib.error.HTTPError as error:
        return error.code, error.read()
    except urllib.error.URLError as error:
        raise VerificationError(f"GNS3 API unavailable: {error.reason}") from error


def nodes(api):
    status, body = api_request(api, f"/v2/projects/{PROJECT_ID}/nodes")
    if status != 200:
        raise VerificationError(f"node-list status={status}: {body.decode(errors='replace')}")
    return {node["name"]: node for node in json.loads(body)}


def node_status(api, node_id):
    status, body = api_request(api, f"/v2/projects/{PROJECT_ID}/nodes/{node_id}")
    if status != 200:
        raise VerificationError(f"node-status status={status}: {body.decode(errors='replace')}")
    return json.loads(body)["status"]


def wait_for(api, node_id, expected):
    deadline = time.monotonic() + 90
    while time.monotonic() < deadline:
        if node_status(api, node_id) == expected:
            return
        time.sleep(2)
    raise VerificationError(f"node {node_id} did not reach {expected} within 90 seconds")


def start(api, node):
    status, body = api_request(
        api, f"/v2/projects/{PROJECT_ID}/nodes/{node['node_id']}/start", method="POST"
    )
    if status not in (200, 201, 202, 204):
        raise VerificationError(f"{node['name']} start status={status}: {body.decode(errors='replace')}")
    wait_for(api, node["node_id"], "started")


def restart(api, node):
    status, body = api_request(
        api, f"/v2/projects/{PROJECT_ID}/nodes/{node['node_id']}/stop", method="POST"
    )
    if status not in (200, 201, 202, 204):
        raise VerificationError(f"{node['name']} stop status={status}: {body.decode(errors='replace')}")
    wait_for(api, node["node_id"], "stopped")
    start(api, node)


def ensure_running(api, selected):
    """Best-effort recovery if a stop succeeded but a later step failed."""
    outcomes = {}
    for name, node in selected.items():
        try:
            if node_status(api, node["node_id"]) != "started":
                start(api, node)
            outcomes[name] = "started"
        except Exception as error:
            outcomes[name] = f"recovery_failed: {type(error).__name__}: {error}"
    return outcomes


def console_capture(port, password, command):
    """Use telnet negotiation and delimit output after disabling command echo."""
    begin = "__OPS01_BEGIN_6ed155b8__"
    end = "__OPS01_END_6ed155b8__"
    last_error = None
    for attempt in range(3):
        client = None
        echo_disabled = False
        try:
            client = telnetlib.Telnet("127.0.0.1", port, timeout=8)
            client.write(b"\n")
            deadline = time.monotonic() + 12
            prompt = b""
            while time.monotonic() < deadline and b"login:" not in prompt and b"# " not in prompt:
                time.sleep(0.4)
                prompt += client.read_very_eager()
            if b"login:" in prompt:
                client.write(b"root\n")
                client.read_until(b"Password:", timeout=8)
                client.write(password.encode() + b"\n")
                client.read_until(b"# ", timeout=8)
            elif b"# " not in prompt:
                raise VerificationError(f"console {port} did not yield a login or shell prompt")
            client.write(b"stty -echo\n")
            client.read_until(b"# ", timeout=8)
            echo_disabled = True
            client.write(f"printf '{begin}\\n'\n".encode())
            client.write(command.encode() + b"\n")
            client.write(f"printf '{end}\\n'\n".encode())
            data = client.read_until(end.encode(), timeout=30).decode(errors="replace")
            if begin not in data or end not in data:
                raise VerificationError(f"console {port} did not return complete markers")
            client.write(b"stty echo\n")
            echo_disabled = False
            return data.split(begin, 1)[1].split(end, 1)[0].replace("\r", "").strip()
        except (OSError, EOFError, VerificationError) as error:
            last_error = error
            time.sleep(2)
        finally:
            if client is not None:
                if echo_disabled:
                    try:
                        client.write(b"stty echo\n")
                    except (OSError, EOFError):
                        pass
                client.close()
    raise VerificationError(f"console {port} unavailable after 3 attempts: {last_error}")


def section(output, name):
    start = f"__{name}_BEGIN__"
    end = f"__{name}_END__"
    if start not in output or end not in output:
        raise VerificationError(f"missing {name} markers in post-marker console output")
    return output.split(start, 1)[1].split(end, 1)[0].strip()


def web_command():
    return "; ".join((
        "printf '__IFACES_BEGIN__\\n'; cat /etc/network/interfaces; printf '__IFACES_END__\\n'",
        "printf '__SAMBA_BEGIN__\\n'; testparm -s 2>&1; rc=$?; printf '__SAMBA_RC=%s__\\n' \"$rc\"; printf '__SAMBA_END__\\n'",
        "printf '__SHARES_BEGIN__\\n'; count=0; for f in /srv/share/general/* /srv/share/ventas/*; do [ -f \"$f\" ] || continue; count=$((count+1)); ls -ln \"$f\"; sha256sum \"$f\"; done; printf '__SHARE_COUNT=%s__\\n' \"$count\"; printf '__SHARES_END__\\n'",
        "printf '__HTTP_BEGIN__\\n'; wget -q -T 5 -O - http://127.0.0.1/; rc=$?; printf '\\n__HTTP_RC=%s__\\n' \"$rc\"; printf '__HTTP_END__\\n'",
    ))


def admin_command():
    return "; ".join((
        "printf '__IFACES_BEGIN__\\n'; cat /etc/network/interfaces; printf '__IFACES_END__\\n'",
        "printf '__ADDR_BEGIN__\\n'; ip -4 addr show dev eth0; ip -4 route show default; printf '__ADDR_END__\\n'",
        "printf '__SMB_TCP_BEGIN__\\n'; nc -zw2 172.16.0.20 445; rc=$?; printf '__SMB_TCP_RC=%s__\\n' \"$rc\"; printf '__SMB_TCP_END__\\n'",
    ))


def snapshot_once(node, password):
    if not isinstance(node.get("console"), int):
        raise VerificationError(f"{node['name']} has no integer console port")
    output = console_capture(node["console"], password, web_command() if node["name"] == "web1" else admin_command())
    ifaces = section(output, "IFACES")
    if node["name"] == "web1":
        samba, shares, http = section(output, "SAMBA"), section(output, "SHARES"), section(output, "HTTP")
        if "__SAMBA_RC=0__" not in samba or "[general]" not in samba or "[ventas]" not in samba:
            raise VerificationError("web1 Samba configuration is not readable with both expected shares")
        if "__SHARE_COUNT=0__" in shares or not re.search(r"^[0-9a-f]{64}\\s", shares, re.MULTILINE):
            raise VerificationError("web1 share file metadata/content hashes were not collected")
        if "__HTTP_RC=0__" not in http or "web1 utp-network-lab OK" not in http:
            raise VerificationError("web1 HTTP marker was not returned successfully")
        return {"console": node["console"], "interfaces": ifaces, "samba": samba, "shares": shares, "http": http}
    address, smb_tcp = section(output, "ADDR"), section(output, "SMB_TCP")
    if "iface eth0 inet dhcp" not in ifaces:
        raise VerificationError("admin-vm DHCP configuration is absent")
    if "inet 192.168.20." not in address or "default via 192.168.20.1" not in address:
        raise VerificationError("admin-vm does not have a valid VLAN20 lease and default gateway")
    if "__SMB_TCP_RC=0__" not in smb_tcp:
        raise VerificationError("admin-vm cannot reach web1 TCP/445")
    return {"console": node["console"], "interfaces": ifaces, "address": address, "smb_tcp": smb_tcp}


def snapshot(node, password):
    last_error = None
    for attempt in range(1, 4):
        try:
            return snapshot_once(node, password)
        except VerificationError as error:
            last_error = error
            if attempt < 3:
                time.sleep(5)
    raise VerificationError(f"{node['name']} snapshot failed after 3 attempts: {last_error}")


def compare(before, after):
    return {
        "web1": all(before["web1"][key] == after["web1"][key] for key in ("interfaces", "samba", "shares", "http")),
        "admin-vm": before["admin-vm"]["interfaces"] == after["admin-vm"]["interfaces"],
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--api", default=DEFAULT_API)
    parser.add_argument("--password-file", default=DEFAULT_PASSWORD_FILE)
    args = parser.parse_args()
    result = {"observed_utc": datetime.now(timezone.utc).isoformat(), "requirement": "OPS01"}
    selected = {}
    recovery_nodes = {}
    try:
        available = nodes(args.api)
        missing = [name for name in NODES if name not in available]
        if missing:
            raise VerificationError(f"required nodes missing: {', '.join(missing)}")
        selected = {name: available[name] for name in NODES}
        result["initial_node_states"] = {name: node.get("status") for name, node in selected.items()}
        unexpected = [name for name, node in selected.items() if node.get("status") not in ("started", "stopped")]
        if unexpected:
            raise VerificationError(f"required nodes have unsupported initial states: {', '.join(unexpected)}")
        result["baseline_start_actions"] = {}
        for name, node in selected.items():
            if node.get("status") == "stopped":
                start(args.api, node)
                result["baseline_start_actions"][name] = "started_from_stopped"
            else:
                result["baseline_start_actions"][name] = "already_started"
        fw1 = available.get("fw1")
        if fw1 is None:
            result["fw1_support_action"] = "not_present"
        elif fw1.get("status") == "stopped":
            start(args.api, fw1)
            result["fw1_support_action"] = "started_from_stopped_for_vlan20_to_dmz_smb_path"
        elif fw1.get("status") == "started":
            result["fw1_support_action"] = "already_started"
        else:
            result["fw1_support_action"] = f"not_started: {fw1.get('status')}"
        recovery_nodes = dict(selected)
        if result["fw1_support_action"] in (
            "started_from_stopped_for_vlan20_to_dmz_smb_path", "already_started"
        ):
            recovery_nodes["fw1"] = fw1
        password = Path(args.password_file).read_text(encoding="utf-8").strip()
        if not password:
            raise VerificationError("protected password file is empty")
        result["before"] = {name: snapshot(selected[name], password) for name in NODES}
        for name in NODES:
            restart(args.api, selected[name])
        refreshed = nodes(args.api)
        result["after"] = {name: snapshot(refreshed[name], password) for name in NODES}
        result["comparison"] = compare(result["before"], result["after"])
        result["status"] = "PASS" if all(result["comparison"].values()) else "FAIL"
    except Exception as error:
        result["status"] = "NOT_EVALUATED"
        result["reason"] = f"{type(error).__name__}: {error}"
    finally:
        if selected:
            result["final_node_states"] = ensure_running(args.api, recovery_nodes or selected)
            if any(state != "started" for state in result["final_node_states"].values()):
                result["status"] = "NOT_EVALUATED"
                result["reason"] = "Node recovery failed; inspect final_node_states"
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
