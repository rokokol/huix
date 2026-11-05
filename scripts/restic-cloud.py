#!/usr/bin/env python3

import argparse
import configparser
import fcntl
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tempfile
import time
from contextlib import contextmanager


MARKER = ".huix-restic-cloud.json"
FORMAT = "huix-restic-cloud-v1"
NAME = re.compile(r"[a-zA-Z0-9][a-zA-Z0-9_.-]*\Z")
OBJECT = re.compile(
    r"[a-zA-Z0-9][a-zA-Z0-9_.-]*/(?:config|(?:keys|index|snapshots)/[0-9a-f]{64}"
    r"|data/[0-9a-f]{2}/[0-9a-f]{64})\Z"
)


class Error(Exception):
    pass


class Rclone:
    def __init__(self, config):
        self.config = config

    def run(self, *args, missing_ok=False, input=None):
        result = subprocess.run(
            ["rclone", "--config", str(self.config), *map(str, args)],
            input=input, text=True, stdout=subprocess.PIPE, check=False,
        )
        if missing_ok and result.returncode == 3:
            return "[]"
        if result.returncode:
            raise Error(f"rclone {args[0]} failed with status {result.returncode}")
        return result.stdout


@contextmanager
def config_lock(config):
    spec = importlib.util.spec_from_file_location(
        "drive_backup_cloud", Path(__file__).with_name("drive-backup.py")
    )
    if spec is None or spec.loader is None:
        raise Error("Cannot load the shared configuration lock")
    core = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = core
    spec.loader.exec_module(core)
    try:
        core.private_config(config)
        with core.config_lock(config):
            yield
    except core.BackupError as error:
        raise Error(str(error)) from error


def sha256(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def inventory(source, expected):
    repos = set()
    result = {}
    for root, directories, files in os.walk(source, followlinks=False):
        root = Path(root)
        for name in directories + files:
            path = root / name
            if path.is_symlink():
                raise Error("A repository snapshot contains a symbolic link")
        for name in files:
            path = root / name
            relative = path.relative_to(source).as_posix()
            if "/locks/" in relative:
                raise Error("A repository was locked at the snapshot boundary; retry later")
            if relative == ".htpasswd":
                continue
            if not OBJECT.fullmatch(relative) or not stat.S_ISREG(path.stat().st_mode):
                raise Error("A snapshot contains a file outside the restic layout")
            repo = relative.split("/", 1)[0]
            repos.add(repo)
            result[relative] = (path.stat().st_size, sha256(path))
    if not expected or not expected <= repos:
        raise Error("An expected restic repository is missing")
    for repo in repos:
        if (f"{repo}/config" not in result
                or not any(p.startswith(f"{repo}/keys/") for p in result)
                or not any(p.startswith(f"{repo}/snapshots/") for p in result)):
            raise Error("A repository has no config, key, or completed snapshot")
    return result, repos


def remote_inventory(rclone, destination):
    items = json.loads(rclone.run(
        "lsjson", destination, "--recursive", "--files-only",
        "--hash", "--hash-type", "SHA-256", missing_ok=True,
    ))
    result = {}
    for item in items:
        path = item["Path"]
        if path in result:
            raise Error("The destination contains duplicate object paths")
        if path != MARKER and not OBJECT.fullmatch(path):
            raise Error("The destination contains a file outside the managed restic layout")
        digest = item.get("Hashes", {}).get("sha256", "")
        if not re.fullmatch(r"[0-9a-fA-F]{64}", digest):
            raise Error("The destination did not supply a SHA-256 hash")
        result[path] = (item["Size"], digest.lower())
    return result


def account_fingerprint(config, destination):
    parser = configparser.RawConfigParser()
    try:
        with config.open() as stream:
            parser.read_file(stream)
        remote = destination.split(":", 1)[0]
        settings = dict(parser.items(remote)) if parser.has_section(remote) else {}
        token = json.loads(settings.pop("token", "{}"))
        if not isinstance(token, dict):
            raise ValueError
    except (configparser.Error, ValueError) as error:
        raise Error("Cannot read the selected rclone account") from error
    identity = {"destination": destination, "settings": settings,
                "refresh_token": token.get("refresh_token")}
    return hashlib.sha256(json.dumps(identity, sort_keys=True).encode()).hexdigest()


def save_state(path, data):
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as stream:
        temporary = Path(stream.name)
        try:
            json.dump(data, stream)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
            os.replace(temporary, path)
        finally:
            temporary.unlink(missing_ok=True)


def mirror(source, destination, expected, rclone, state):
    local, repos = inventory(source, expected)
    marker_text = json.dumps({"format": FORMAT}, sort_keys=True) + "\n"
    marker_bytes = marker_text.encode()
    marker = (len(marker_bytes), hashlib.sha256(marker_bytes).hexdigest())
    remote = remote_inventory(rclone, destination)
    if remote:
        if remote.get(MARKER) != marker:
            raise Error("The destination is not an owned restic mirror")
    else:
        rclone.run("rcat", destination.rstrip("/") + "/" + MARKER, input=marker_text)
    for path in local.keys() & remote.keys():
        if local[path] != remote[path]:
            raise Error("An existing immutable restic object differs; no file was replaced")
    with tempfile.TemporaryDirectory(prefix="restic-cloud-") as directory:
        file_list = Path(directory) / "files"
        # Publish snapshot references only after their data, keys and indexes arrive
        for snapshots in (False, True):
            paths = sorted(p for p in local if p not in remote
                           and ("/snapshots/" in p) == snapshots)
            if paths:
                file_list.write_text("\n".join(paths) + "\n")
                rclone.run("copy", source, destination, "--immutable", "--checksum",
                           "--files-from-raw", file_list)
        uploaded = remote_inventory(rclone, destination)
        if (uploaded.get(MARKER) != marker
                or any(uploaded.get(path) != details for path, details in local.items())):
            raise Error("The uploaded repository does not match the snapshot")
        # Remove obsolete references before the packs that they could reference
        stale = uploaded.keys() - local.keys() - {MARKER}
        for snapshots in (True, False):
            paths = sorted(p for p in stale if ("/snapshots/" in p) == snapshots)
            if paths:
                file_list.write_text("\n".join(paths) + "\n")
                rclone.run("delete", destination, "--files-from-raw", file_list)
    final = remote_inventory(rclone, destination)
    if final != {**local, MARKER: marker}:
        raise Error("The final mirror inventory differs from the snapshot")
    save_state(state, {"time": int(time.time()), "repositories": sorted(repos),
                       "files": len(local),
                       "account": account_fingerprint(rclone.config, destination)})


def check_age(state, max_age, config, destination):
    if not state.is_file():
        raise Error("The cloud mirror has no successful run")
    data = json.loads(state.read_text())
    if data.get("account") != account_fingerprint(config, destination):
        raise Error("The selected account or destination has no successful cloud mirror")
    timestamp = data["time"]
    age = time.time() - timestamp
    if age < 0 or age > max_age:
        raise Error("The last successful cloud mirror is too old")


def latest_snapshot(directory):
    candidates = [path for path in directory.iterdir()
                  if re.fullmatch(r"restic\.\d{8}T\d{4,6}(?:_\d+)?", path.name)
                  and path.is_dir() and not path.is_symlink()]
    if not candidates:
        raise Error("There is no restic Btrfs snapshot")
    def order(path):
        stamp, _, suffix = path.name.partition("_")
        date, clock = stamp.split("T")
        return date, clock.ljust(6, "0"), int(suffix or "0")

    snapshot = max(candidates, key=order)
    result = subprocess.run(
        ["btrfs", "property", "get", "-ts", str(snapshot), "ro"],
        text=True, stdout=subprocess.PIPE, check=True,
    )
    if result.stdout.strip() != "ro=true":
        raise Error("The selected snapshot is not read-only")
    return snapshot


def main():
    parser = argparse.ArgumentParser(
        description="Copy encrypted restic repositories from a read-only Btrfs snapshot"
    )
    commands = parser.add_subparsers(dest="command", required=True)
    backup = commands.add_parser("mirror", help="Update an owned cloud mirror")
    backup.add_argument("--snapshot-dir", type=Path, required=True)
    backup.add_argument("--accounts", type=Path, required=True,
                        help="Read expected repository names from the rest-server htpasswd")
    backup.add_argument("--destination", required=True)
    backup.add_argument("--config", type=Path, required=True)
    backup.add_argument("--lock", type=Path, required=True)
    backup.add_argument("--state", type=Path, required=True)
    check = commands.add_parser("check", help="Fail when the last successful mirror is too old")
    check.add_argument("--state", type=Path, required=True)
    check.add_argument("--max-age", type=int, required=True, help="Maximum age in seconds")
    check.add_argument("--config", type=Path, required=True)
    check.add_argument("--destination", required=True)
    args = parser.parse_args()
    try:
        if args.command == "check":
            check_age(args.state, args.max_age, args.config, args.destination)
        else:
            expected = set()
            for line in args.accounts.read_text().splitlines():
                if line and not line.startswith("#"):
                    name = line.split(":", 1)[0]
                    if not NAME.fullmatch(name):
                        raise Error("The rest-server account name is not a safe repository name")
                    if name != "metrics":
                        expected.add(name)
            with config_lock(args.config), args.lock.open("r+") as lock:
                fcntl.flock(lock, fcntl.LOCK_EX)
                source = latest_snapshot(args.snapshot_dir)
                mirror(source, args.destination, expected, Rclone(args.config), args.state)
        return 0
    except (Error, OSError, ValueError, KeyError, configparser.Error,
            subprocess.CalledProcessError) as error:
        print(f"restic-cloud: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
