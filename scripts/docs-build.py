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


def strip_lua_comments(text):
    """The Lua text without its comments, so a bind inside a comment is not read as a bind"""
    lines = []
    for line in text.splitlines():
        quote = None
        cut = len(line)
        for index, character in enumerate(line):
            if quote:
                if character == quote and line[index - 1] != "\\":
                    quote = None
            elif character in "\"'":
                quote = character
            elif line.startswith("--", index):
                cut = index
                break
        lines.append(line[:cut])
    return "\n".join(lines)


def balanced(text, start, opening="(", closing=")"):
    """The text between the bracket at start and the one that closes it"""
    depth = 0
    quote = None
    for index in range(start, len(text)):
        character = text[index]
        if quote:
            if character == quote and text[index - 1] != "\\":
                quote = None
            continue
        if character in "\"'":
            quote = character
        elif character == opening:
            depth += 1
        elif character == closing:
            depth -= 1
            if depth == 0:
                return text[start + 1 : index], index + 1
    raise ValueError("незакрытая скобка")


def split_args(body):
    """Top-level arguments of a Lua call, split on the commas that are not inside anything"""
    args = []
    depth = 0
    quote = None
    current = []
    for index, character in enumerate(body):
        if quote:
            if character == quote and body[index - 1] != "\\":
                quote = None
        elif character in "\"'":
            quote = character
        elif character in "({[":
            depth += 1
        elif character in ")}]":
            depth -= 1
        elif character == "," and depth == 0:
            args.append("".join(current))
            current = []
            continue
        current.append(character)
    tail = "".join(current).strip()
    if tail:
        args.append(tail)
    return [arg.strip() for arg in args]


def unquote(text):
    """The content of a Lua string literal, or None when the text is not one"""
    text = text.strip()
    if len(text) >= 2 and text[0] == text[-1] and text[0] in "\"'":
        return text[1:-1]
    return None


def describe_dispatcher(expression, constants):
    """The dispatcher a bind calls and the argument it hands over"""
    match = re.match(r"hl\.dsp\.([A-Za-z_]+)(?:\.([A-Za-z_]+))?\s*\(", expression)
    if not match:
        # A local function that builds a dispatcher, such as the workspace tab helper
        plain = re.match(r"([A-Za-z_][\w.]*)\s*\(", expression.strip())
        if not plain:
            return expression.strip(), ""
        body, _ = balanced(expression.strip(), plain.end() - 1)
        return plain.group(1), body.strip()
    dispatcher = ".".join(part for part in match.groups() if part)
    body, _ = balanced(expression, match.end() - 1)
    call = body.strip()
    literal = unquote(call)
    if literal is not None:
        return dispatcher, literal
    if call in constants:
        return dispatcher, constants[call]
    return dispatcher, call


def parse_binds(text):
    """Every live bind of the Hyprland Lua config, with the keys it sits on"""
    constants = dict(re.findall(r'^\s*local\s+([A-Za-z_]\w*)\s*=\s*"([^"]*)"', text, re.MULTILINE))
    live = strip_lua_comments(text)
    binds = []
    position = 0
    while True:
        found = live.find("hl.bind(", position)
        if found < 0:
            return binds
        body, position = balanced(live, found + len("hl.bind"))
        args = split_args(body)
        if len(args) < 2:
            continue
        keys = unquote(args[0])
        if keys is None:
            continue
        dispatcher, argument = describe_dispatcher(args[1], constants)
        options = args[2] if len(args) > 2 else ""
        binds.append(
            {
                "keys": keys,
                "dispatcher": dispatcher,
                "argument": argument,
                "repeating": "repeating=true" in options.replace(" ", ""),
            }
        )


def file_comment(text):
    """The comment block that comes before any body code, where a module says why it exists"""
    lines = text.splitlines()
    depth = 0
    index = 0
    while index < len(lines):
        stripped = lines[index].strip()
        if not stripped:
            index += 1
            continue
        if stripped.startswith("#"):
            block = []
            while index < len(lines) and lines[index].strip().startswith("#"):
                block.append(lines[index].strip().lstrip("#").strip())
                index += 1
            return "\n".join(block).strip() or None
        depth += sum(stripped.count(bracket) for bracket in "{[(") - sum(stripped.count(bracket) for bracket in "}])")
        if depth <= 0 and stripped.endswith(":"):
            depth = 0
        elif depth <= 0:
            return None
        index += 1
    return None


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
        groups.setdefault(option_group(option["name"]), []).append(option)
    return groups


def option_group(name):
    """The group an option name belongs to: its module, or the prefix when it sits straight under it"""
    parts = name.split(".")
    return parts[1] if len(parts) > 2 else parts[0]


def paragraphs(comment):
    """A comment block as prose, with a blank comment line starting a new paragraph"""
    blocks = (block.strip() for block in re.split(r"\n\s*\n", comment))
    return "\n\n".join(block for block in blocks if block)


def render_modules(entries):
    """One section per module: its path, the reason its comment gives, and what it declares"""
    parts = []
    for entry in entries:
        lines = [f"## `{entry['path']}`"]
        if entry["comment"]:
            lines.append(paragraphs(entry["comment"]))
        if entry["options"]:
            names = ", ".join(f"`{name}`" for name in entry["options"])
            groups = sorted({option_group(name) for name in entry["options"]})
            links = ", ".join(f"[опции rokokol.{group}](../options/{group}.md)" for group in groups)
            lines.append(f"**Опции:** {names}\n\nПодробнее: {links}")
        if entry["units"]:
            lines.append("**Юниты:** " + ", ".join(f"`{unit}`" for unit in entry["units"]))
        parts.append("\n\n".join(lines))
    return "\n\n".join(parts)


def render_bindings(binds):
    """Every bind of the compositor as one table"""
    rows = [
        [
            f"`{bind['keys'].replace('|', chr(92) + '|')}`",
            f"`{bind['dispatcher']}`",
            format_value(bind["argument"]) if bind["argument"] else "—",
            "да" if bind["repeating"] else "—",
        ]
        for bind in binds
    ]
    return table(["Клавиши", "Диспетчер", "Аргумент", "Держится"], rows)


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
    pattern = re.compile(re.escape(start) + r".*?" + re.escape(END), re.DOTALL)
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
    front = [f"title: {title}", f"kind: {marker.split()[0]}"]
    # A page about files describes no host: the module of a workstation and the one of the
    # station live in the same directory, and naming every host would be false for both
    if hosts:
        front.append(f"hosts: [{', '.join(hosts)}]")
    return (
        "---\n"
        + "\n".join(front)
        + "\n---\n\n"
        + f"# {title}\n\n{START.format(marker=marker)}\n\n{END}\n"
    )


def options_by_file(facts):
    """Every option a given file declares, whichever host asked first"""
    by_file = {}
    for cfg in facts["hosts"].values():
        for option in cfg["options"]:
            for declaration in option["declarations"]:
                by_file.setdefault(declaration, set()).add(option["name"])
    return {name: sorted(names) for name, names in by_file.items()}


def module_pages(sources, facts):
    """One page per directory, a section per module inside it"""
    declared = options_by_file(facts)
    directories = {}
    for path, text in sources.items():
        if not path.endswith(".nix"):
            continue
        directory = str(Path(path).parent)
        directories.setdefault(directory, []).append(
            {
                "path": path,
                "comment": file_comment(text),
                "options": declared.get(path, []),
                "units": sorted(declared_units({path: text})),
            }
        )
    pages = {}
    for directory, entries in sorted(directories.items()):
        slug = "root" if directory == "." else directory.replace("/", "-")
        pages[DOCS / "modules" / f"{slug}.md"] = (
            f"module {directory}",
            render_modules(sorted(entries, key=lambda entry: entry["path"])),
        )
    return pages


def bindings_page(sources):
    """The compositor binds, read out of the Lua that declares them"""
    binds = []
    for path in sorted(sources):
        if path.endswith(".lua"):
            binds += parse_binds(sources[path])
    return {DOCS / "bindings.md": ("bindings", render_bindings(binds))}


def main(argv):
    parser = argparse.ArgumentParser(description="Render flake facts into the documentation corpus")
    parser.add_argument("command", choices=("inject", "check", "show", "scaffold"))
    parser.add_argument("--facts", required=True, type=Path)
    parser.add_argument("--repo", default=Path("."), type=Path)
    args = parser.parse_args(argv)

    facts = json.loads(args.facts.read_text(encoding="utf-8"))
    sources = read_sources(args.repo)
    blocks = host_pages(facts, sources) | option_pages(facts) | module_pages(sources, facts) | bindings_page(sources)

    if args.command == "scaffold":
        for path, (marker, _) in sorted(blocks.items()):
            page = args.repo / path
            if page.exists():
                continue
            parts = marker.split(None, 1)
            kind = parts[0]
            key = parts[1] if len(parts) > 1 else ""
            hosts = [key] if kind == "host" else (sorted(facts["hosts"]) if kind == "option" else [])
            if kind == "host":
                title = f"Хост {key}"
            elif kind == "option":
                title = "Опции верхнего уровня" if key == "rokokol" else f"Опции rokokol.{key}"
            elif kind == "module":
                title = "Корень репозитория" if key == "." else f"Модули {key}"
            else:
                title = "Клавиши Hyprland"
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
