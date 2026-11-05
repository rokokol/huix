import base64
import copy
import json
import os
import socket
import subprocess
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path


POLICY = json.loads(Path(sys.argv[1]).read_text())
RULES = {rule["uid"]: rule for rule in POLICY["definitions"]["rules"]}
LIMITS = POLICY["definitions"]["limits"]


def check_formulas(root):
    # promtool evaluates every rule of a group for every case at every step, and a case spans a
    # week, so each rule gets its own group and its own specification
    cases = {uid: [] for uid in RULES}

    # A week case samples every half hour and looks at its last sample, because Prometheus drops
    # a series five minutes after one. The other cases need a handful of samples, and promtool
    # evaluates a rule at each step of the longest window in the case, so those stop at an hour
    def case(name, rule, series, expected, week=True, every="30m", at="7d23h30m"):
        cases[rule].append({
            "name": name,
            "interval": every if week else "10m",
            "input_series": [{"series": metric, "values": values} for metric, values in series.items()],
            "promql_expr_test": [{
                "expr": f"count(({RULES[rule]['expr']}) > 0) or vector(0)",
                "eval_time": at if week else "1h",
                "exp_samples": [{"labels": "{}", "value": expected}],
            }],
        })

    # A week of half-hour samples, which is coarser than any real source and still exercises
    # the whole window, keeps each of these cases to the cost of one forecast
    for prefix in ("mail", "vpn"):
        metric = f'{prefix}_disk_used_ratio{{job="{prefix}",instance="fixture"}}'
        push = f'push_time_seconds{{job="{prefix}",instance="fixture"}}'
        fresh = {push: "0+1800x575"}
        case(f"{prefix}: rising disk fills within a week", f"{prefix}-disk-forecast",
             {metric: "0.4+0.002x575", **fresh}, 1)
        case(f"{prefix}: a flat disk does not fill", f"{prefix}-disk-forecast",
             {metric: "0.5+0x575", **fresh}, 0)
        case(f"{prefix}: stale pushes cannot forecast", f"{prefix}-disk-forecast",
             {metric: "0.4+0.002x575", push: "0+0x575"}, 0)
        case(f"{prefix}: a day of history cannot forecast", f"{prefix}-disk-forecast",
             {metric: "0.4+0.002x144", push: "0+600x144"}, 0, week=False)
        # Present at both ends of the week and rising, but sampled a few times a day: two points
        # fit any line, so the forecast must wait for a real history
        case(f"{prefix}: a sparse history cannot forecast", f"{prefix}-disk-forecast",
             {metric: "0.4+0.002x168", push: "0+3600x168"}, 0, every="1h", at="7d")
        case(f"{prefix}: the node reports its own full disk, not Grafana", "station-disk-full",
             {metric: "1+0x6", **fresh}, 0, week=False)

    station = POLICY["station"]
    selector = f'host="{station}",device="/dev/sda",fstype="ext4",mountpoint="/"'
    size = f"node_filesystem_size_bytes{{{selector}}}"
    available = f"node_filesystem_avail_bytes{{{selector}}}"
    writable = f"node_filesystem_readonly{{{selector}}}"
    disks = {size: "1000+0x575", available: "600-2x575", writable: "0+0x575"}
    case("station forecast uses available space", "station-disk-forecast", disks, 1)
    case("read-only volumes do not raise disk forecasts", "station-disk-forecast",
         {**disks, writable: "1+0x575"}, 0)
    case("a workstation cannot raise a capacity alert", "station-disk-full",
         {key.replace(station, "nixos-pc"): value for key, value in {**disks, available: "1+0x6"}.items()},
         0, week=False)
    for high in (False, True):
        share = LIMITS["diskUsed"] + (0.01 if high else -0.01)
        case(f"station disk threshold {high}", "station-disk-full",
             {size: "1000+0x6", available: f"{round((1 - share) * 1000)}+0x6", writable: "0+0x6"},
             int(high), week=False)
    for high in (False, True):
        value = LIMITS["cpuTemperature"] + (1 if high else -1)
        case(f"CPU temperature threshold {high}", "station-cpu-hot", {
            f'node_hwmon_temp_celsius{{host="{station}",chip="cpu",sensor="temp1"}}': f"{value}+0x6",
            f'node_hwmon_chip_names{{host="{station}",chip="cpu",chip_name="coretemp"}}': "1+0x6",
        }, int(high), week=False)
        value = LIMITS["diskTemperature"] + (1 if high else -1)
        case(f"disk temperature threshold {high}", "station-disk-hot", {
            f'smartctl_device_temperature{{host="{station}",device="sda",temperature_type="current"}}': f"{value}+0x6",
            f'smartctl_device_temperature{{host="{station}",device="sda",temperature_type="critical_limit_max"}}': "100+0x6",
        }, int(high), week=False)
    for host in (station, "nixos-pc", "nixos-laptop"):
        labels = f'host="{host}",device="sda"'
        case(f"{host}: failed SMART health", "smart-health", {
            f"smartctl_device_smart_status{{{labels}}}": "0+0x6",
        }, 1, week=False)
        for growing in (False, True):
            # The growth sits inside the last day, which is the window the rules look back on
            value = "0+0x4 1+0x2" if growing else "5+0x6"
            case(f"{host}: new sector errors {growing}", "smart-sectors-new", {
                f'smartctl_device_attribute{{{labels},attribute_name="Reallocated_Sector_Ct",attribute_value_type="raw"}}': value,
            }, int(growing), week=False)
            case(f"{host}: new media errors {growing}", "nvme-media-new", {
                f"smartctl_device_media_errors{{{labels}}}": value,
            }, int(growing), week=False)
        case(f"{host}: pending sectors need attention", "smart-sectors-pending", {
            f'smartctl_device_attribute{{{labels},attribute_name="Current_Pending_Sector",attribute_value_type="raw"}}': "2+0x6",
        }, 1, week=False)
        case(f"{host}: NVMe warning is a bit mask", "nvme-critical", {
            f"smartctl_device_critical_warning{{{labels}}}": "4+0x6",
        }, 1, week=False)
        case(f"{host}: new Btrfs errors", "btrfs-errors-new", {
            f'node_btrfs_device_errors_total{{{labels},type="read"}}': "0+0x4 1+0x2",
        }, 1, week=False)

    # The rules are independent, so promtool checks them side by side: a week of samples for one
    # rule already takes most of a minute on its own
    def verify(uid):
        rule, own = RULES[uid], cases[uid]
        rules_path = root / f"{uid}.rules.json"
        rules_path.write_text(json.dumps({"groups": [{
            "name": uid,
            "rules": [{"alert": uid, "expr": f"({rule['expr']}) > 0", "for": rule["for"]}],
        }]}))
        subprocess.run(["promtool", "check", "rules", str(rules_path)], check=True)
        specification = root / f"{uid}.tests.json"
        specification.write_text(json.dumps({"rule_files": [str(rules_path)], "tests": own}))
        subprocess.run(["promtool", "test", "rules", str(specification)], check=True)

    with ThreadPoolExecutor(max_workers=os.cpu_count()) as pool:
        list(pool.map(verify, cases))
    print(f"Verified {sum(map(len, cases.values()))} PromQL cases", flush=True)


def port():
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        return listener.getsockname()[1]


def provisioned_rules(grafana_port):
    request = urllib.request.Request(f"http://127.0.0.1:{grafana_port}/api/v1/provisioning/alert-rules")
    token = f"admin:{os.environ['GRAFANA_PASSWORD']}".encode()
    request.add_header("Authorization", "Basic " + base64.b64encode(token).decode())
    with urllib.request.urlopen(request, timeout=10) as answer:
        return json.load(answer)


def wait_for(description, predicate, processes):
    deadline = time.monotonic() + 90
    while time.monotonic() < deadline:
        for process in processes:
            if process.poll() is not None:
                raise AssertionError(f"A service exited with {process.returncode}: {description}")
        try:
            if predicate():
                return
        except (OSError, ValueError, urllib.error.URLError):
            pass
        time.sleep(0.2)
    raise AssertionError(f"Timeout: {description}")


def check_runtime(root):
    prom_port, grafana_port, bridge_port = port(), port(), port()
    healthy = False

    class Metrics(BaseHTTPRequestHandler):
        def do_GET(self):
            self.send_response(200)
            # Prometheus refuses a target that names no format, and 3.x picks the parser by it
            self.send_header("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
            self.end_headers()
            self.wfile.write(f'smartctl_device_smart_status{{host="fixture",device="bad"}} {int(healthy)}\n'.encode())

        def log_message(self, format, *args):
            pass

    metrics = HTTPServer(("127.0.0.1", 0), Metrics)
    threading.Thread(target=metrics.serve_forever, daemon=True).start()
    state = root / "bridge"
    state.mkdir()
    provisioning = root / "provisioning"
    (provisioning / "alerting").mkdir(parents=True)
    (provisioning / "datasources").mkdir()
    # Grafana reads every provisioning directory it knows and logs an error for each absent one,
    # so the ones this test fills nothing into exist all the same
    (provisioning / "dashboards").mkdir()
    (provisioning / "plugins").mkdir()
    provision = copy.deepcopy(POLICY["provisioning"])
    for group in provision["rules"]["groups"]:
        group["interval"] = "10s"
        for rule in group["rules"]:
            # The fast run below drops the pending period, so the provisioned one is checked first
            assert rule["for"] == RULES[rule["uid"]]["for"], (
                f"{rule['uid']} carries {rule.get('for')} instead of its pending period"
            )
            rule["for"] = "0s"
    receiver = provision["contactPoints"]["contactPoints"][0]["receivers"][0]
    receiver["settings"]["url"] = f"http://127.0.0.1:{bridge_port}/alerts"
    route = provision["policies"]["policies"][0]
    route.update(group_wait="0s", group_interval="10s", repeat_interval="10m")
    for name, value in provision.items():
        (provisioning / "alerting" / f"{name}.yaml").write_text(json.dumps(value))
    (provisioning / "datasources" / "prometheus.yaml").write_text(json.dumps({
        "apiVersion": 1,
        "datasources": [{"name": "Prometheus", "uid": POLICY["datasource"], "type": "prometheus",
                         "url": f"http://127.0.0.1:{prom_port}", "access": "proxy", "isDefault": True}],
    }))
    config = root / "grafana.ini"
    config.write_text(f"""[paths]
data = {root}/grafana-data
logs = {root}/grafana-logs
plugins = {os.environ['GRAFANA_PLUGINS']}
provisioning = {provisioning}
[server]
http_addr = 127.0.0.1
http_port = {grafana_port}
[security]
admin_password = {os.environ['GRAFANA_PASSWORD']}
[analytics]
reporting_enabled = false
check_for_updates = false
check_for_plugin_updates = false
[grafana_net]
url = http://127.0.0.1:1
[unified_alerting]
min_interval = 10s
[database]
# Every rule evaluates here every 10 s, where the station's own rules run every minute, so the
# readers and the rule state writer meet far more often than they do in place. WAL stops a
# reader from blocking the writer, which is the only thing this compression makes collide; the
# retry settings stay at their defaults, so a lock that survives is still an error
wal = true
[plugins]
preinstall_disabled = true
public_key_retrieval_disabled = true
""")
    prom_config = root / "prometheus.json"
    prom_config.write_text(json.dumps({
        "global": {"scrape_interval": "1s"},
        "scrape_configs": [{"job_name": "fixture", "static_configs": [{"targets": [f"127.0.0.1:{metrics.server_port}"]}]}],
    }))
    processes, logs = [], []

    def start(name, command):
        log = (root / f"{name}.log").open("w+")
        logs.append((name, log))
        processes.append(subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT))

    try:
        start("bridge", [sys.executable, "-B", str(Path(__file__).resolve().parents[1] / "grafana-alerts.py"),
                         "--address", "127.0.0.1", "--port", str(bridge_port), "--state-dir", str(state)])
        start("prometheus", ["prometheus", f"--config.file={prom_config}", f"--storage.tsdb.path={root}/tsdb",
                             f"--web.listen-address=127.0.0.1:{prom_port}"])
        start("grafana", ["grafana", "server", "--homepath", os.environ["GRAFANA_HOME"], "--config", str(config)])
        causes = state / "causes"
        wait_for("Grafana loads the provisioned rules",
                 lambda: len(provisioned_rules(grafana_port)) == len(RULES), processes)
        wait_for("Grafana raises a SMART alert through the webhook",
                 lambda: causes.exists() and "SMART health check failed" in causes.read_text(), processes)
        healthy = True
        wait_for("Grafana sends recovery through the webhook", lambda: not causes.read_text(), processes)
        print("Grafana loaded the rules and sent firing and resolved webhooks", flush=True)
    finally:
        metrics.shutdown()
        for process in reversed(processes):
            process.terminate()
        for process in reversed(processes):
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        for name, log in logs:
            log.seek(0)
            print(f"--- {name} log ---\n{log.read()}")
            log.close()


with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    for step in (check_formulas, check_runtime):
        started = time.monotonic()
        step(root)
        print(f"{step.__name__} took {time.monotonic() - started:.0f} s", flush=True)
