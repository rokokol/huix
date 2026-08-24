"""Manage sing-box profiles as systemd template instances.

A profile is one file in /etc/sing-box/profiles holding a single outbound tagged `proxy`; the
shared base comes from Nix. Switching is `systemctl start sing-box@<name>`.
"""

import base64
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlparse

# Relocates every path at once, so the tool can be exercised outside root
ROOT = Path(os.environ.get("SKVPN_ROOT", "/"))
CONF = ROOT / "etc/sing-box"
PROFILES = CONF / "profiles"
SUB_URL = CONF / "subscription.url"
MANIFEST = CONF / "subscription.profiles"
STAMP = ROOT / "var/lib/skvpn/last-sync"
ACTIVE = ROOT / "var/lib/skvpn/active"
UNIT = "sing-box@{}.service"
MAX_AGE = 24 * 3600

# Cloudflare's bot rules answer 403 to the stock Python-urllib agent
USER_AGENT = "skvpn/1"


def die(msg):
    print(f"skvpn: {msg}", file=sys.stderr)
    sys.exit(1)


def need_root():
    if os.geteuid() != 0 and "SKVPN_ROOT" not in os.environ:
        die("needs root — try `sudo skvpn …`")


def slug(name):
    # No dots: they become the systemd instance name, where a leading one gets escaped
    return re.sub(r"[^A-Za-z0-9_-]", "-", name)


def profile_path(name):
    return PROFILES / f"{slug(name)}.json"


def profile_names():
    return sorted(p.stem for p in PROFILES.glob("*.json"))


def remembered():
    return ACTIVE.read_text().strip() if ACTIVE.exists() else None


def forget(name):
    """Drop the boot choice when the profile behind it goes away."""
    if remembered() == name:
        ACTIVE.unlink()
        print(f"     {name} was the boot choice, boot now starts nothing")


def systemctl(*args):
    probe = subprocess.run(
        ["systemctl", *args], capture_output=True, text=True, check=False
    )
    if probe.returncode != 0:
        die(probe.stderr.strip().splitlines()[0] if probe.stderr.strip() else "systemctl failed")


def running():
    # Asked of systemd, not of the profile directory, which an unprivileged user cannot read
    probe = subprocess.run(
        ["systemctl", "list-units", "--plain", "--no-legend", "--state=active", "sing-box@*"],
        capture_output=True,
        text=True,
        check=False,
    )
    for line in probe.stdout.splitlines():
        unit = line.split()[0]
        if unit.startswith("sing-box@") and unit.endswith(".service"):
            return unit.removeprefix("sing-box@").removesuffix(".service")
    return None


# --- URI → sing-box outbound ------------------------------------------------


def parse_vless(url, q):
    node = {
        "type": "vless",
        "server": url.hostname,
        "server_port": url.port or 443,
        "uuid": unquote(url.username or ""),
    }
    if q.get("flow"):
        node["flow"] = q["flow"]

    if q.get("security") in ("tls", "reality"):
        tls = {"enabled": True, "server_name": q.get("sni", url.hostname)}
        if q.get("fp"):
            tls["utls"] = {"enabled": True, "fingerprint": q["fp"]}
        if q.get("security") == "reality":
            tls["reality"] = {"enabled": True, "public_key": q.get("pbk", "")}
            if q.get("sid"):
                tls["reality"]["short_id"] = q["sid"]
        if q.get("alpn"):
            tls["alpn"] = q["alpn"].split(",")
        node["tls"] = tls

    network = q.get("type", "tcp")
    if network == "ws":
        node["transport"] = {"type": "ws", "path": q.get("path", "/")}
        if q.get("host"):
            node["transport"]["headers"] = {"Host": q["host"]}
    elif network == "grpc":
        node["transport"] = {"type": "grpc", "service_name": q.get("serviceName", "")}
    elif network == "httpupgrade":
        node["transport"] = {"type": "httpupgrade", "path": q.get("path", "/")}
    elif network not in ("tcp", "raw"):
        raise ValueError(f"transport {network!r} has no sing-box equivalent")

    return node


def parse_hysteria2(url, q):
    node = {
        "type": "hysteria2",
        "server": url.hostname,
        "server_port": url.port or 443,
        "password": unquote(url.username or ""),
        "tls": {"enabled": True, "server_name": q.get("sni", url.hostname)},
    }
    if q.get("insecure") == "1":
        node["tls"]["insecure"] = True
    if q.get("obfs"):
        node["obfs"] = {"type": q["obfs"], "password": q.get("obfs-password", "")}
    return node


def parse_trojan(url, q):
    node = {
        "type": "trojan",
        "server": url.hostname,
        "server_port": url.port or 443,
        "password": unquote(url.username or ""),
        "tls": {"enabled": True, "server_name": q.get("sni", url.hostname)},
    }
    if q.get("alpn"):
        node["tls"]["alpn"] = q["alpn"].split(",")
    return node


PARSERS = {
    "vless": parse_vless,
    "hysteria2": parse_hysteria2,
    "hy2": parse_hysteria2,
    "trojan": parse_trojan,
}


def uri_to_profile(uri):
    """Return (name, config) for a share link, or raise ValueError."""
    url = urlparse(uri.strip())
    parser = PARSERS.get(url.scheme)
    if parser is None:
        raise ValueError(f"scheme {url.scheme!r} is not supported by sing-box")
    node = parser(url, {k: v[0] for k, v in parse_qs(url.query).items()})
    node["tag"] = "proxy"
    name = unquote(url.fragment) or url.hostname
    return name, {"outbounds": [node]}


def write_profile(name, config):
    PROFILES.mkdir(parents=True, exist_ok=True)
    path = profile_path(name)
    path.write_text(json.dumps(config, indent=2) + "\n")
    # The unit runs as the sing-box user, and these carry node credentials
    path.chmod(0o640)
    return path


# --- subscription -----------------------------------------------------------


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=20) as resp:
        raw = resp.read().decode()
    try:
        return base64.b64decode(raw + "===").decode()
    except Exception:
        return raw


def sync(if_stale=False):
    if not SUB_URL.exists():
        # The timer runs this before any subscription is stored; that is not a failure
        if if_stale:
            return
        die("no subscription stored — run `skvpn sub set <url>` first")
    if if_stale and STAMP.exists() and time.time() - STAMP.stat().st_mtime < MAX_AGE:
        return
    url = SUB_URL.read_text().strip()

    try:
        body = fetch(url)
    except (urllib.error.URLError, OSError) as exc:
        active = running()
        hint = f" — {active} is up, so the fetch went through it" if active else ""
        die(f"subscription unreachable: {exc}{hint}")

    seen = []
    for uri in (line for line in body.splitlines() if "://" in line):
        try:
            name, config = uri_to_profile(uri)
        except ValueError as exc:
            print(f"  skip  {exc}")
            continue
        path = write_profile(name, config)
        seen.append(path.stem)
        print(f"  +  {path.stem}")

    if not seen:
        die("subscription carried nothing sing-box can speak")

    # Drop what this subscription used to carry and no longer does; the manifest is what tells
    # those apart from profiles added by hand, which are never touched
    previous = set(MANIFEST.read_text().split()) if MANIFEST.exists() else set()
    for gone in sorted(previous - set(seen)):
        path = profile_path(gone)
        if path.exists() and running() != gone:
            path.unlink()
            print(f"  -  {gone}")
            forget(gone)
    MANIFEST.write_text("\n".join(seen) + "\n")

    STAMP.parent.mkdir(parents=True, exist_ok=True)
    STAMP.write_text(url + "\n")


# --- commands ---------------------------------------------------------------


def cmd_sub(args):
    need_root()
    if args[:1] == ["set"]:
        if len(args) != 2:
            die("usage: skvpn sub set <url>")
        CONF.mkdir(parents=True, exist_ok=True)
        SUB_URL.write_text(args[1] + "\n")
        SUB_URL.chmod(0o600)
        print("  stored")
        sync()
    elif args[:1] == ["sync"] or not args:
        sync(if_stale="--if-stale" in args)
    else:
        die("usage: skvpn sub [set <url> | sync [--if-stale]]")


def cmd_add(args):
    need_root()
    if not args:
        die("usage: skvpn add <uri>…")
    for uri in args:
        try:
            name, config = uri_to_profile(uri)
        except ValueError as exc:
            print(f"  skip  {exc}")
            continue
        print(f"  +  {write_profile(name, config).stem}")


def cmd_rm(args):
    need_root()
    if not args:
        die("usage: skvpn rm <name>…")
    for name in args:
        path = profile_path(name)
        if not path.exists():
            die(f"no such profile: {name}")
        if running() == path.stem:
            die(f"{path.stem} is up — `skvpn down` first")
        path.unlink()
        print(f"  -  {path.stem}")
        forget(path.stem)


def cmd_ls(_args):
    active = running()
    if not os.access(PROFILES, os.R_OK):
        die(f"cannot read {PROFILES} — try `sudo skvpn ls`")
    for name in profile_names():
        node = json.loads(profile_path(name).read_text())["outbounds"][0]
        mark = "*" if name == active else " "
        print(f" {mark} {name:<24} {node['type']:<10} {node['server']}")


def cmd_up(args):
    need_root()
    if len(args) != 1:
        die("usage: skvpn up <name>")
    name = slug(args[0])
    if not profile_path(name).exists():
        die(f"no such profile: {name}")
    sync(if_stale=True)
    cmd_down([])
    systemctl("start", UNIT.format(name))
    # Remembered only once it is up, so a broken profile is not replayed on every boot
    ACTIVE.parent.mkdir(parents=True, exist_ok=True)
    ACTIVE.write_text(name + "\n")
    print(f"  →  {name}")


def cmd_down(_args):
    need_root()
    active = running()
    if active:
        systemctl("stop", UNIT.format(active))
        print(f"  ×  {active}")
    ACTIVE.unlink(missing_ok=True)


def cmd_restore(_args):
    """Boot-time half of `up` — no fetching and no choosing, just what was last up."""
    need_root()
    name = remembered()
    if name is None:
        return
    if not profile_path(name).exists():
        die(f"remembered profile is gone: {name}")
    systemctl("start", "--no-block", UNIT.format(name))
    print(f"  →  {name}")


def cmd_status(_args):
    active = running()
    print(f"  profile   {active or 'none'}")
    if remembered():
        print(f"  on boot   {remembered()}")
    if STAMP.exists():
        age = int((time.time() - STAMP.stat().st_mtime) / 60)
        print(f"  synced    {age} min ago")


COMMANDS = {
    "sub": cmd_sub,
    "add": cmd_add,
    "rm": cmd_rm,
    "ls": cmd_ls,
    "up": cmd_up,
    "down": cmd_down,
    "restore": cmd_restore,
    "status": cmd_status,
}


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in COMMANDS:
        die(f"usage: skvpn {{{'|'.join(COMMANDS)}}} …")
    COMMANDS[sys.argv[1]](sys.argv[2:])


if __name__ == "__main__":
    main()
