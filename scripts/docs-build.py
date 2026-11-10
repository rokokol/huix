#!/usr/bin/env python3
"""Render the facts a host resolves to into the pages of the documentation corpus"""

import argparse
import json
from pathlib import Path
import re
import sys

# A unit of this repository is the one its sources declare: the list of a host's units also holds
# every unit nixpkgs defines, and a page about this setup must not read as a page about NixOS
UNIT = re.compile(r"systemd\.(?:user\.)?(?:services|timers)\.([A-Za-z0-9_@:-]+)")

START = "<!-- generated: {marker} -->"
END = "<!-- /generated -->"

DOCS = Path("docs")

# A source tree the generator scans for the units, options and bindings this repository declares
SCANNED = ("nixos", "home-manager", "lib", "scripts", "flake.nix", "checks.nix")


class MarkerMissing(Exception):
    """A page that should carry a generated block does not carry its marker"""


def format_value(value):
    """One fact as a table cell or an inline value"""
    if value is None:
        return "—"
    if isinstance(value, bool):
        return "да" if value else "нет"
    if isinstance(value, (int, float)):
        return f"`{value}`"
    if isinstance(value, str):
        return f"`{value.replace('|', chr(92) + '|')}`"
    if isinstance(value, list):
        return ", ".join(format_value(item) for item in value) if value else "—"
    if isinstance(value, dict):
        return ", ".join(f"`{key}={format_value(item).strip('`')}`" for key, item in value.items())
    return f"`{value}`"


def declared_units(sources):
    """Every systemd unit and timer the given sources declare"""
    names = set()
    for text in sources.values():
        for match in UNIT.finditer(text):
            names.add(match.group(1).rstrip("."))
    return names


def owns_unit(name, sources):
    return name in declared_units(sources)


def group_options(options):
    """Options by the first segment under the prefix, which is the module that declares them"""
    groups = {}
    for option in options:
        parts = option["name"].split(".")
        # An option sits either inside a per-service namespace or straight under the prefix, and
        # the second kind has no module name of its own to group under
        key = parts[1] if len(parts) > 2 else parts[0]
        groups.setdefault(key, []).append(option)
    return groups


def bullet(items, sources=None):
    """A line of names, or a word saying there are none"""
    names = [name for name in items if sources is None or name in sources]
    if not names:
        return "нет"
    return ", ".join(f"`{name}`" for name in sorted(names))


def table(header, rows):
    if not rows:
        return "нет"
    lines = ["| " + " | ".join(header) + " |", "| " + " | ".join("---" for _ in header) + " |"]
    lines += ["| " + " | ".join(row) + " |" for row in rows]
    return "\n".join(lines)


def render_host(facts, sources):
    """The generated half of a host page"""
    units = declared_units(sources)
    parts = ["Система: `{}`".format(facts["system"])]

    parts.append("**Службы из этого репозитория:** " + bullet(facts["services"], units))
    parts.append("**Таймеры:** " + bullet(facts["timers"], units))

    if facts["tailnet"]:
        rows = [
            [f"`{name}`", format_value(site["port"]), "да" if site["lan"] else "нет"]
            for name, site in sorted(facts["tailnet"].items())
        ]
        parts.append("Веб-службы в частной сети\n\n" + table(["Служба", "Порт", "В домашней сети"], rows))

    firewall = [f"TCP {format_value(facts['firewall']['tcp'])}", f"UDP {format_value(facts['firewall']['udp'])}"]
    parts.append("**Файрвол открывает:** " + ", ".join(firewall))
    parts.append("**Секреты sops по имени:** " + bullet(facts["secrets"]))

    if facts["sessionVariables"]:
        rows = [[f"`{name}`", format_value(value)] for name, value in sorted(facts["sessionVariables"].items())]
        parts.append("Переменные сессии\n\n" + table(["Переменная", "Значение"], rows))

    if facts["homeValues"]:
        rows = [[f"`rokokol.{name}`", format_value(value)] for name, value in sorted(facts["homeValues"].items())]
        parts.append("Опции Home Manager\n\n" + table(["Опция", "Значение"], rows))

    return "\n\n".join(parts)


def inject(text, marker, rendered):
    """Replace the content of a generated block, keeping the prose around it"""
    start = START.format(marker=marker)
    if start not in text:
        raise MarkerMissing(f"нет маркера {start}")
    body = rendered.strip()
    pattern = re.compile(re.escape(start) + r".*?" + re.escape(END), re.S)
    return pattern.sub(lambda _: f"{start}\n\n{body}\n\n{END}", text)


def read_sources(repo):
    """The text of every file the generator reads for declarations"""
    sources = {}
    for name in SCANNED:
        path = repo / name
        if path.is_file():
            sources[name] = path.read_text(encoding="utf-8")
            continue
        if not path.is_dir():
            continue
        for child in sorted(path.rglob("*")):
            if child.suffix in {".nix", ".lua", ".sh", ".py", ".toml"} and child.is_file():
                sources[str(child.relative_to(repo))] = child.read_text(encoding="utf-8")
    return sources


def host_pages(facts, sources):
    """The generated blocks of the host pages, keyed by the page path"""
    return {DOCS / "hosts" / f"{name}.md": (f"host {name}", render_host(cfg, sources)) for name, cfg in facts["hosts"].items()}


def option_pages(facts):
    """The generated blocks of the option pages, keyed by the page path"""
    by_host = {name: group_options(cfg["options"]) for name, cfg in facts["hosts"].items()}
    groups = sorted({group for groups in by_host.values() for group in groups})
    pages = {}
    for group in groups:
        names = [name for name in by_host if group in by_host[name]]
        rows = []
        for option in by_host[names[0]][group]:
            values = []
            for name in names:
                found = next((item for item in by_host[name][group] if item["name"] == option["name"]), None)
                values.append(format_value(found["value"]) if found else "—")
            rows.append([f"`{option['name']}`", *values, option["description"] or "—"])
        header = ["Опция", *names, "Описание"]
        files = sorted({declaration for option in by_host[names[0]][group] for declaration in option["declarations"]})
        body = table(header, rows) + "\n\nОбъявлено в: " + ", ".join(f"`{name}`" for name in files)
        pages[DOCS / "options" / f"{group}.md"] = (f"option {group}", body)
    return pages


def scaffold(marker, title, hosts):
    """A new page: its heading, the hosts it describes, and the marker the generator fills"""
    return (
        "---\n"
        f"title: {title}\n"
        f"kind: {marker.split()[0]}\n"
        f"hosts: [{', '.join(hosts)}]\n"
        "---\n\n"
        f"# {title}\n\n"
        f"{START.format(marker=marker)}\n\n{END}\n"
    )


def main(argv):
    parser = argparse.ArgumentParser(description="Render flake facts into the documentation corpus")
    parser.add_argument("command", choices=("inject", "check", "show", "scaffold"))
    parser.add_argument("--facts", required=True, type=Path)
    parser.add_argument("--repo", default=Path("."), type=Path)
    args = parser.parse_args(argv)

    facts = json.loads(args.facts.read_text(encoding="utf-8"))
    sources = read_sources(args.repo)
    blocks = host_pages(facts, sources) | option_pages(facts)

    if args.command == "scaffold":
        for path, (marker, _) in sorted(blocks.items()):
            page = args.repo / path
            if page.exists():
                continue
            kind, key = marker.split()
            hosts = [key] if kind == "host" else sorted(facts["hosts"])
            title = f"Хост {key}" if kind == "host" else ("Опции верхнего уровня" if key == "rokokol" else f"Опции rokokol.{key}")
            page.parent.mkdir(parents=True, exist_ok=True)
            page.write_text(scaffold(marker, title, hosts), encoding="utf-8")
            print(f"created {path}")
        return 0

    stale = []
    for path, (marker, rendered) in sorted(blocks.items()):
        page = args.repo / path
        if not page.exists():
            print(f"missing page {path}")
            continue
        text = page.read_text(encoding="utf-8")
        try:
            updated = inject(text, marker, rendered)
        except MarkerMissing as error:
            print(error)
            continue
        if updated != text:
            stale.append(str(path))
            if args.command == "inject":
                page.write_text(updated, encoding="utf-8")
        if args.command == "show":
            print(updated)

    for path in stale:
        print(f"{'updated' if args.command == 'inject' else 'stale'} {path}")
    if args.command == "check" and stale:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
