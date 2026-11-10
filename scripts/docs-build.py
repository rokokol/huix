#!/usr/bin/env python3
"""Render the facts a host resolves to into the pages of the documentation corpus"""

import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

# A unit of this repository is the one its sources declare: the list of a host's units also holds
# every unit nixpkgs defines, and a page about this setup must not read as a page about NixOS
UNIT = re.compile(r"systemd\.(?:user\.)?(?:services|timers)\.([A-Za-z0-9_@:-]+)")

START = "<!-- generated: {marker} -->"
END = "<!-- /generated -->"

# A page names the file behind every fact it shows, so a reader lands where the fact changes
REPO = "https://github.com/rokokol/huix"


def repo_link(path):
    """A path in this repository as a link to the file itself"""
    return f"[`{path}`]({REPO}/blob/master/{path})"

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
        lines = [f"## {repo_link(entry['path'])}"]
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


def render_bindings(binds, sources=()):
    """Every bind of the compositor as one table, with the file that declares them"""
    rows = [
        [
            f"`{bind['keys'].replace('|', chr(92) + '|')}`",
            f"`{bind['dispatcher']}`",
            format_value(bind["argument"]) if bind["argument"] else "—",
            "да" if bind["repeating"] else "—",
        ]
        for bind in binds
    ]
    body = table(["Клавиши", "Диспетчер", "Аргумент", "Держится"], rows)
    if sources:
        body += "\n\nОбъявлено в: " + ", ".join(repo_link(name) for name in sources)
    return body


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

    # The configuration file of a host is named after the host without its role prefix, which is
    # the one convention the repository keeps for it
    configuration = f"nixos/configuration-{facts['name'].removeprefix('nixos-')}.nix"
    if configuration in sources:
        parts.append("Настраивается в " + repo_link(configuration))

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
        body = table(header, rows) + "\n\nОбъявлено в: " + ", ".join(repo_link(name) for name in files)
        pages[DOCS / "options" / f"{group}.md"] = (f"option {group}", body)
    return pages


def scaffold(marker, title, hosts, described=""):
    """A new page: its heading, the hosts it describes and the marker the generator fills"""
    front = [f"title: {title}", f"kind: {marker.split()[0]}"]
    # A page about files describes no host: the module of a workstation and the one of the
    # station live in the same directory, and naming every host would be false for both
    if hosts:
        front.append(f"hosts: [{', '.join(hosts)}]")
    if described:
        front.append(f"dir: {described}")
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
    declaring = []
    for path in sorted(sources):
        if path.endswith(".lua"):
            found = parse_binds(sources[path])
            binds += found
            if found:
                declaring.append(path)
    return {DOCS / "bindings.md": ("bindings", render_bindings(binds, declaring))}


def parse_front(text):
    """The front matter a page carries and the body after it"""
    if not text.startswith("---\n"):
        return {}, text
    end = text.find("\n---\n", 4)
    if end < 0:
        return {}, text
    meta = {}
    for line in text[4:end].splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        value = value.strip()
        if value.startswith("[") and value.endswith("]"):
            meta[key.strip()] = [item.strip() for item in value[1:-1].split(",") if item.strip()]
        else:
            meta[key.strip()] = value
    return meta, text[end + 5 :]


def to_page_links(html):
    """A link between corpus pages opens the rendered page; a link that leaves the corpus keeps
    its markdown target, which resolves to the file in the repository"""

    def swap(match):
        target = match.group(1)
        if target.startswith(("http://", "https://", "../../", "/")) or not target.endswith(".md"):
            return match.group(0)
        return match.group(0)[: -len(".md\"")] + '.html"'

    return re.sub(r'href="([^"]+)"', swap, html)


IMAGE = re.compile(r"<img\b[^>]*>")
PARAGRAPH_OF_IMAGES = re.compile(r"<p>\s*((?:<img\b[^>]*>\s*)+)</p>")


def to_figures(html):
    """A paragraph that holds images alone becomes a frame of the kit, with the alt text as its
    caption: a picture in this corpus is a figure of the document, not a character of a sentence"""

    def frame(match):
        figures = []
        for tag in IMAGE.finditer(match.group(1)):
            element = tag.group(0)
            alt = re.search(r'alt="([^"]*)"', element)
            caption = alt.group(1) if alt else ""
            figures.append(f'<figure class="ddlc-snap">{element}<figcaption>{caption}</figcaption></figure>')
        return "".join(figures)

    return PARAGRAPH_OF_IMAGES.sub(frame, html)


def to_local_links(html, root):
    """A picture a page references beside its markdown resolves against the page it was written
    for, which on the site is one level up from the page of the corpus"""

    def swap(match):
        return f'src="{root}{match.group(1)}"'

    return re.sub(r'src="\.\./([^"]+)"', swap, html)


def page_label(title, path):
    """What a page is called in the navigation"""
    if title:
        return title
    return Path(path).stem


def navigation(pages):
    """Pages grouped by the directory that names their section, in the order the sections are
    read and with the root section last

    A module page remembers the directory it describes in its front matter, so the navigation
    can group it by the layer it belongs to instead of offering one flat list of sixty paths"""
    sections = {}
    for path, meta in pages:
        directory = str(Path(path).parent)
        described = meta.get("dir")
        group = described.split("/")[0] if described else None
        label = described.split("/", 1)[1] if described and "/" in described else page_label(meta.get("title"), path)
        # The section already says these are options, so the entry names the group alone
        if meta.get("kind") == "option":
            label = Path(path).stem
        sections.setdefault(directory, []).append({"path": path, "label": label, "group": group})
    order = [key for key in SECTIONS if key in sections]
    order += sorted(key for key in sections if key not in SECTIONS)
    return [(directory, sorted(sections[directory], key=lambda item: item["label"])) for directory in order]


SECTIONS = {
    "hosts": "Хосты",
    "options": "Опции",
    "modules": "Модули",
    ".": "Обзор",
}

SHELL = """<!DOCTYPE html>
<html lang="ru">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} — huix</title>
<script>
  try {{
    const t = localStorage.getItem("huix-theme")
    if (t === "light" || t === "dark") document.documentElement.dataset.theme = t
  }} catch {{}}
</script>
<link rel="stylesheet" href="{root}assets/vendor/ddlc/ddlc-tokens.css">
<link rel="stylesheet" href="{root}assets/vendor/ddlc/ddlc-ui.css">
<link rel="stylesheet" href="{root}assets/vendor/ddlc/ddlc-report.css">
<link rel="stylesheet" href="{root}assets/site.css">
<script type="module" src="{root}assets/site.js"></script>
</head>
<body>
<header class="top"><div class="wrap top-inner">
<a class="brand" href="{root}index.html">huix <span class="tagline">конфиг и то, что на нём работает</span></a>
<button class="icon-button" data-theme-toggle type="button"><svg viewBox="0 0 8 8" width="16" height="16" aria-hidden="true"><path d="" fill-rule="evenodd"></path></svg></button>
<a class="icon-button" href="https://github.com/rokokol/huix" aria-label="huix на GitHub"><img src="{root}assets/icon-github.svg" alt="" width="16" height="16"></a>
</div></header>
<div class="wrap layout">
<nav class="sidebar">{sidebar}</nav>
<main class="doc">{main}</main>
</div>
</body>
</html>
"""


def sidebar_html(sections, current, root):
    blocks = []
    for directory, items in sections:
        name = SECTIONS.get(directory, directory)
        links = []
        group = None
        for item in items:
            if item["group"] != group:
                group = item["group"]
                links.append(f'<li class="nav-group">{group}</li>')
            target = item["path"][: -len(".md")] + ".html"
            mark = ' aria-current="page"' if target == current else ""
            links.append(f'<li><a href="{root}{target}"{mark}>{item["label"]}</a></li>')
        blocks.append(f'<h2>{name}</h2><ul>{"".join(links)}</ul>')
    return "".join(blocks)


def render_site(repo, out, assets):
    """Every corpus page as a page of the site, plus the index"""
    import markdown

    pages = []
    for path in sorted((repo / DOCS).rglob("*.md")):
        relative = str(path.relative_to(repo / DOCS))
        meta, body = parse_front(path.read_text(encoding="utf-8"))
        pages.append((relative, meta, body))

    sections = navigation([(relative, meta) for relative, meta, _ in pages])
    shutil.copytree(assets, out / "assets", dirs_exist_ok=True)
    # The pictures of the corpus live beside it, in docs/img, as the pictures of a README live
    # beside the README
    pictures = repo / DOCS / "img"
    if pictures.is_dir():
        shutil.copytree(pictures, out / "img", dirs_exist_ok=True)

    for relative, meta, body in pages:
        target = relative[: -len(".md")] + ".html"
        root = "../" * (len(Path(relative).parts) - 1)
        main = markdown.markdown(body, extensions=["tables", "fenced_code", "toc", "sane_lists"])
        page = SHELL.format(
            title=page_label(meta.get("title"), relative),
            root=root,
            sidebar=sidebar_html(sections, target, root),
            main=f'<article class="prose">{to_figures(to_local_links(to_page_links(main), root))}</article>',
        )
        destination = out / target
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(page, encoding="utf-8")

    index = ["<h1>huix</h1>", '<article class="prose"><p>Документация по этому конфигу: что где лежит, что чем включается и почему сделано так. Каждая страница собрана из файлов самого репозитория.</p>']
    for directory, items in sections:
        name = SECTIONS.get(directory, directory)
        links = "".join(f'<li><a href="{item["path"][: -len(".md")]}.html">{item["label"]}</a></li>' for item in items)
        index.append(f"<h2>{name}</h2><ul>{links}</ul>")
    index.append("</article>")
    (out / "index.html").write_text(
        SHELL.format(title="Документация", root="", sidebar=sidebar_html(sections, "index.html", ""), main="".join(index)),
        encoding="utf-8",
    )
    return len(pages)


def script_files(sources):
    """The scripts a reader calls, which are the ones at the top of scripts/ rather than the
    helpers beside them or the tests of them"""
    return sorted(
        path for path in sources if path.startswith("scripts/") and path.count("/") == 1 and path.endswith((".sh", ".py"))
    )


def help_text(repo, path):
    """What a script prints for --help, with a status that says whether the print happened"""
    runner = ["bash", str(repo / path)] if path.endswith(".sh") else [sys.executable, "-B", str(repo / path)]
    try:
        done = subprocess.run(runner + ["--help"], capture_output=True, text=True, timeout=20, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return {"path": path, "help": "", "ok": False}
    printed = (done.stdout + done.stderr).strip()
    return {"path": path, "help": printed, "ok": done.returncode == 0 and bool(printed)}


def render_scripts(entries):
    """One section per script: its path, and the help it prints, which is the only description
    that cannot disagree with the script itself"""
    parts = []
    for entry in entries:
        lines = [f"## {repo_link(entry['path'])}"]
        if entry["ok"]:
            lines.append("```\n" + entry["help"].replace("```", "'''") + "\n```")
        else:
            lines.append("Скрипт не печатает `--help`: запускать без аргументов или читать текст выше")
        parts.append("\n\n".join(lines))
    return "\n\n".join(parts)


def scripts_page(repo, sources):
    """The page of the scripts, filled from what each one prints"""
    entries = [help_text(repo, path) for path in script_files(sources)]
    return {DOCS / "scripts.md": ("scripts", render_scripts(entries))}


def main(argv):
    parser = argparse.ArgumentParser(description="Render flake facts into the documentation corpus")
    parser.add_argument("command", choices=("inject", "check", "show", "scaffold", "site"))
    parser.add_argument("--facts", required=True, type=Path)
    parser.add_argument("--repo", default=Path("."), type=Path)
    parser.add_argument("--out", default=Path("site/_build"), type=Path)
    args = parser.parse_args(argv)

    if args.command == "site":
        pages = render_site(args.repo, args.repo / args.out, args.repo / "site" / "assets")
        print(f"собрано {pages} страниц в {args.out}")
        return 0

    facts = json.loads(args.facts.read_text(encoding="utf-8"))
    sources = read_sources(args.repo)
    blocks = (
        host_pages(facts, sources)
        | option_pages(facts)
        | module_pages(sources, facts)
        | bindings_page(sources)
        | scripts_page(args.repo, sources)
    )

    if args.command == "scaffold":
        for path, (marker, _) in sorted(blocks.items()):
            page = args.repo / path
            if page.exists():
                continue
            parts = marker.split(None, 1)
            kind = parts[0]
            key = parts[1] if len(parts) > 1 else ""
            hosts = [key] if kind == "host" else (sorted(facts["hosts"]) if kind == "option" else [])
            described = key if kind == "module" else ""
            if kind == "host":
                title = f"Хост {key}"
            elif kind == "option":
                title = "Опции верхнего уровня" if key == "rokokol" else f"Опции rokokol.{key}"
            elif kind == "module":
                title = "Корень репозитория" if key == "." else key
            elif kind == "scripts":
                title = "Скрипты"
            else:
                title = "Клавиши Hyprland"
            page.parent.mkdir(parents=True, exist_ok=True)
            page.write_text(scaffold(marker, title, hosts, described), encoding="utf-8")
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
