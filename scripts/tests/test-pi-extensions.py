import argparse
import json
import os
from pathlib import Path
import queue
import subprocess
import tempfile
import threading
import time


COMMANDS = {
    "agents", "intercom", "subs", "automode",
    "btw", "goal", "supi-cache-history", "usage", "heads-up", "bg", "todos",
}


def run(pi, extensions, node):
    with tempfile.TemporaryDirectory(prefix="pi-extensions-") as directory:
        home = Path(directory)
        agent = home / ".pi/agent"
        agent.mkdir(parents=True)
        manifest = json.loads((extensions / "package.json").read_text())
        packages = [str(extensions / "node_modules" / name) for name in manifest["dependencies"]]
        for package in packages:
            assert (Path(package) / "package.json").is_file(), f"Missing package: {package}"
        (agent / "settings.json").write_text(json.dumps({
            "packages": packages,
            "enableInstallTelemetry": False,
            "enableAnalytics": False,
            "defaultProjectTrust": "never",
        }))
        intercom = agent / "intercom"
        intercom.mkdir()
        (intercom / "config.json").write_text(json.dumps({
            "brokerCommand": node,
            "brokerArgs": [str(extensions / "node_modules/tsx/dist/cli.mjs")],
            "inboundTrigger": "never",
        }))
        env = {key: value for key, value in os.environ.items()
               if not any(word in key for word in ("TOKEN", "API_KEY", "SECRET", "CREDENTIAL"))}
        env.update(HOME=directory, PI_CODING_AGENT_DIR=str(agent), PI_TELEMETRY="0", PI_OFFLINE="1")
        process = subprocess.Popen(
            [pi, "--offline", "--mode", "rpc", "--no-session", "--no-context-files"],
            cwd=directory, env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=subprocess.PIPE, text=True,
        )
        events = queue.Queue()
        stderr = []

        def read_stdout():
            for line in process.stdout:
                try:
                    events.put(json.loads(line))
                except ValueError:
                    events.put({"invalid_json": line})

        def read_stderr():
            stderr.extend(process.stderr)

        readers = [threading.Thread(target=read_stdout), threading.Thread(target=read_stderr)]
        for reader in readers:
            reader.start()
        observed = []
        try:
            process.stdin.write(json.dumps({"type": "get_commands", "id": "commands"}) + "\n")
            process.stdin.flush()
            deadline = time.monotonic() + 45
            response = None
            while time.monotonic() < deadline and response is None:
                try:
                    event = events.get(timeout=1)
                except queue.Empty:
                    assert process.poll() is None, f"Pi exited early: {process.returncode}"
                    continue
                observed.append(event)
                if event.get("id") == "commands":
                    response = event
            assert response is not None, "Pi did not answer get_commands"
            assert response.get("success"), response
            names = {command["name"] for command in response["data"]["commands"]}
            assert COMMANDS <= names, f"Missing commands: {sorted(COMMANDS - names)}"
            assert not {"auto-resume", "quota-resume", "codex-resume", "kg"} & names, "Auto-resume is loaded"
            assert "permission-system" not in names, "Duplicate permission gate is loaded"
            for event in observed:
                assert "invalid_json" not in event, event
                assert event.get("type") != "extension_error", event
                if event.get("method") == "notify":
                    assert event.get("notifyType") != "error", event
            print("PASS: all pinned extensions register their commands in offline Pi RPC")
        finally:
            process.terminate()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=10)
            for reader in readers:
                reader.join(timeout=5)
            process.stdin.close()
            process.stdout.close()
            process.stderr.close()
        assert not stderr, "Pi stderr:\n" + "".join(stderr)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--pi", required=True)
    parser.add_argument("--extensions", required=True, type=Path)
    parser.add_argument("--node", required=True)
    args = parser.parse_args()
    run(args.pi, args.extensions, args.node)
