"""Check the dashboard provider migration against a real Grafana database"""

import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request


manifest = json.loads(Path(sys.argv[1]).read_text())


def port():
    """Choose a local port for the test server"""
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        return listener.getsockname()[1]


def request(base, uid):
    """Return Grafana's status and JSON for a dashboard UID"""
    try:
        with urllib.request.urlopen(f"{base}/api/dashboards/uid/{uid}", timeout=2) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as error:
        return error.code, None


def wait_ready(process, base):
    """Wait for the API or fail if Grafana exits"""
    deadline = time.monotonic() + 90
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise AssertionError(f"Grafana exited with {process.returncode}")
        try:
            with urllib.request.urlopen(f"{base}/api/health", timeout=2) as response:
                if response.status == 200:
                    return
        except OSError:
            pass
        time.sleep(0.2)
    raise AssertionError("Grafana did not become ready")


def wait_dashboard(process, base, uid, status):
    """Wait until Grafana provisions or removes the requested dashboard"""
    deadline = time.monotonic() + 90
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise AssertionError(f"Grafana exited with {process.returncode}")
        code, dashboard = request(base, uid)
        if code == status:
            return dashboard
        time.sleep(0.2)
    raise AssertionError(f"Dashboard {uid} did not return HTTP {status}")


def run():
    """Migrate old root dashboards and verify their replacements and folders"""
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        old = root / "old"
        old.mkdir()
        provisioning = root / "provisioning"
        for name in ("dashboards", "datasources", "alerting", "plugins", "notifiers"):
            (provisioning / name).mkdir(parents=True)
        for uid in ("hosts", "guards", "mail", "vpn", "hermes", "hindsight", "ai-spend"):
            (old / f"{uid}.json").write_text(json.dumps({
                "uid": uid, "title": uid, "schemaVersion": 39, "panels": [],
            }))
        address = f"http://127.0.0.1:{port()}"
        config = root / "grafana.ini"
        config.write_text(f"""[paths]
data = {root}/data
logs = {root}/logs
plugins = {os.environ['GRAFANA_PLUGINS']}
provisioning = {provisioning}
[server]
http_addr = 127.0.0.1
http_port = {address.rsplit(':', 1)[1]}
[auth.anonymous]
enabled = true
org_role = Viewer
[analytics]
reporting_enabled = false
check_for_updates = false
check_for_plugin_updates = false
[plugins]
preinstall_disabled = true
public_key_retrieval_disabled = true
""")
        config_file = provisioning / "dashboards" / "providers.yaml"
        logs = []

        def start(providers):
            config_file.write_text(json.dumps({"apiVersion": 1, "providers": providers}))
            log = (root / f"grafana-{len(logs)}.log").open("w+")
            logs.append(log)
            process = subprocess.Popen(
                ["grafana", "server", "--homepath", os.environ["GRAFANA_HOME"], "--config", str(config)],
                stdout=log, stderr=subprocess.STDOUT,
            )
            try:
                wait_ready(process, address)
            except Exception:
                process.terminate()
                process.wait(timeout=30)
                raise
            return process

        def stop(process):
            process.terminate()
            process.wait(timeout=30)

        process = None
        try:
            process = start([{"name": "huix", "type": "file", "options": {"path": str(old)}}])
            for uid in ("hosts", "guards", "mail", "vpn", "hermes", "hindsight", "ai-spend"):
                wait_dashboard(process, address, uid, 200)
            stop(process)
            process = None
            process = start(manifest["providers"])
            for uid in ("hosts", "guards"):
                wait_dashboard(process, address, uid, 404)
            for uid, folder in (("nixos-station", "Hosts"), ("nixos-pc", "Hosts"),
                                ("nixos-laptop", "Hosts"), ("mail", "Services"),
                                ("vpn", "Services"), ("hermes", "AI"),
                                ("hindsight", "AI"), ("ai-spend", "AI")):
                dashboard = wait_dashboard(process, address, uid, 200)
                assert dashboard is not None
                assert dashboard["meta"]["folderTitle"] == folder, f"Dashboard {uid} is in the wrong folder"
                assert dashboard["dashboard"]["tags"], f"Dashboard {uid} has no tags"
            print("Grafana migrated the dashboards to the expected folders")
        finally:
            if process is not None:
                stop(process)
            for log in logs:
                log.seek(0)
                output = log.read()
                log.close()
                errors = [line for line in output.splitlines() if "level=error" in line and "provision" in line.lower()]
                if errors:
                    raise AssertionError("Grafana provisioning errors:\n" + "\n".join(errors))


if __name__ == "__main__":
    run()
