import argparse
import json
import os
import re
from datetime import datetime
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path


def clean(value):
    return " ".join(str(value).split())


def apply(state, payload):
    if not isinstance(payload, dict):
        raise ValueError("Expected an alert object")
    if payload.get("truncatedAlerts", 0):
        raise ValueError("The alert group is incomplete")
    alerts = payload.get("alerts")
    if not isinstance(alerts, list) or len(alerts) > 1000:
        raise ValueError("Expected an alert list with at most 1000 entries")
    result = dict(state)
    for alert in alerts:
        required = ("fingerprint", "status", "startsAt", "labels")
        if not isinstance(alert, dict) or not all(key in alert for key in required):
            raise ValueError("The alert lacks required fields")
        fingerprint = alert["fingerprint"]
        if not re.fullmatch(r"[0-9a-f]{16,64}", fingerprint):
            raise ValueError("Invalid alert fingerprint")
        status = alert["status"]
        if status not in {"firing", "resolved"}:
            raise ValueError("Invalid alert status")
        labels = alert["labels"]
        if labels.get("huix_resource") != "true":
            raise ValueError("The alert does not belong to the resource policy")
        start = datetime.fromisoformat(alert["startsAt"].replace("Z", "+00:00"))
        if start.tzinfo is None:
            raise ValueError("The alert timestamp needs a time zone")
        previous = result.get(fingerprint)
        if previous:
            old = datetime.fromisoformat(previous["start"])
            if start < old or (start == old and previous["status"] == "resolved"):
                continue
        identity = ", ".join(
            f"{key}={clean(value)}"
            for key, value in sorted(labels.items())
            if key not in {"alertname", "grafana_folder", "huix_resource"}
        )
        summary = alert.get("annotations", {}).get("summary", labels["alertname"])
        result[fingerprint] = {
            "start": start.isoformat(),
            "status": status,
            "subject": clean(f"{summary} [{identity}]"),
        }
    return result


def causes(state):
    return "".join(
        f"{key}\t{entry['subject']}\n"
        for key, entry in sorted(state.items())
        if entry["status"] == "firing"
    )


def atomic(path, text):
    temporary = path.with_suffix(".tmp")
    with temporary.open("w") as stream:
        stream.write(text)
        stream.flush()
        os.fsync(stream.fileno())
    temporary.replace(path)


def save(root, state):
    atomic(root / "state.json", json.dumps(state, sort_keys=True))
    atomic(root / "causes", causes(state))


def restore(root):
    path = root / "state.json"
    return json.loads(path.read_text()) if path.exists() else {}


def serve(address, port, root):
    state = restore(root)
    save(root, state)

    class Handler(BaseHTTPRequestHandler):
        def do_POST(self):
            nonlocal state
            if self.path != "/alerts":
                self.send_error(404)
                return
            try:
                length = int(self.headers.get("Content-Length", "0"))
                if not 0 < length <= 1024 * 1024:
                    self.send_error(413)
                    return
                payload = json.loads(self.rfile.read(length))
                updated = apply(state, payload)
                save(root, updated)
                state = updated
            except (ValueError, KeyError, TypeError, AttributeError) as error:
                self.log_error("Invalid alert: %s", error)
                self.send_error(400)
                return
            except OSError as error:
                self.log_error("Cannot save alert: %s", error)
                self.send_error(503)
                return
            self.send_response(200)
            self.end_headers()

        def setup(self):
            super().setup()
            self.connection.settimeout(10)

    HTTPServer((address, port), Handler).serve_forever()


def main():
    parser = argparse.ArgumentParser(description="Pass Grafana webhooks to the alert registry")
    parser.add_argument("--address", required=True)
    parser.add_argument("--port", required=True, type=int)
    parser.add_argument("--state-dir", required=True, type=Path)
    args = parser.parse_args()
    serve(args.address, args.port, args.state_dir)


if __name__ == "__main__":
    main()
