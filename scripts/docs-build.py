#!/usr/bin/env python3
"""Render the facts a host resolves to into the pages of the documentation corpus"""

import argparse
import hashlib
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

# The mark in the tab, which the site takes from the repository rather than keeping a second copy
FAVICON = "can-you-read-this-with-me.jpg"


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
    raise ValueError("unclosed bracket")


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
    """One fact as an inline value, with no table escaping: a cell escapes its own pipes"""
    if value is None:
        return "—"
    if isinstance(value, bool):
        return "yes" if value else "no"
    if isinstance(value, (int, float)):
        return f"`{value}`"
    if isinstance(value, str):
        return f"`{value}`"
    if isinstance(value, list):
        return ", ".join(format_value(item) for item in value) if value else "—"
    if isinstance(value, dict):
        return ", ".join(f"`{key}={format_value(item).strip('`')}`" for key, item in value.items())
    return f"`{value}`"


def cell(text):
    """One table cell. A newline inside a cell ends the row and breaks the table, and a bare pipe
    starts a new column, so both are handled here rather than by every caller"""
    return re.sub(r"\s+", " ", str(text)).strip().replace("|", chr(92) + "|")


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
            links = ", ".join(f"[rokokol.{group} options](../options/{group}.md)" for group in groups)
            lines.append(f"**Options:** {names}\n\nMore: {links}")
        if entry["units"]:
            lines.append("**Units:** " + ", ".join(f"`{unit}`" for unit in entry["units"]))
        parts.append("\n\n".join(lines))
    return "\n\n".join(parts)


def render_bindings(binds, sources=()):
    """Every bind of the compositor as one table, with the file that declares them"""
    rows = [
        [
            format_value(bind["keys"]),
            format_value(bind["dispatcher"]),
            format_value(bind["argument"]) if bind["argument"] else "—",
            "yes" if bind["repeating"] else "—",
        ]
        for bind in binds
    ]
    body = table(["Keys", "Dispatcher", "Argument", "Holds"], rows)
    if sources:
        body += "\n\nDeclared in: " + ", ".join(repo_link(name) for name in sources)
    return body


def bullet(items, sources=None):
    """A line of names, or a word saying there are none"""
    names = [name for name in items if sources is None or name in sources]
    if not names:
        return "none"
    return ", ".join(f"`{name}`" for name in sorted(names))


def table(header, rows):
    if not rows:
        return "none"
    lines = ["| " + " | ".join(cell(text) for text in header) + " |", "| " + " | ".join("---" for _ in header) + " |"]
    lines += ["| " + " | ".join(cell(text) for text in row) + " |" for row in rows]
    return "\n".join(lines)


def render_host(facts, sources):
    """The generated half of a host page"""
    units = declared_units(sources)
    parts = ["System: `{}`".format(facts["system"])]

    # The configuration file of a host is named after the host without its role prefix, which is
    # the one convention the repository keeps for it
    configuration = f"nixos/configuration-{facts['name'].removeprefix('nixos-')}.nix"
    if configuration in sources:
        parts.append("Configured in " + repo_link(configuration))

    parts.append("**Services declared in this repository:** " + bullet(facts["services"], units))
    parts.append("**Timers:** " + bullet(facts["timers"], units))

    if facts["tailnet"]:
        rows = [
            [format_value(name), format_value(site["port"]), "yes" if site["lan"] else "no"]
            for name, site in sorted(facts["tailnet"].items())
        ]
        parts.append("Web services on the private network\n\n" + table(["Service", "Port", "On the home network"], rows))

    firewall = [f"TCP {format_value(facts['firewall']['tcp'])}", f"UDP {format_value(facts['firewall']['udp'])}"]
    parts.append("**The firewall opens:** " + ", ".join(firewall))
    parts.append("**Sops secrets, by name:** " + bullet(facts["secrets"]))

    if facts["sessionVariables"]:
        rows = [[format_value(name), format_value(value)] for name, value in sorted(facts["sessionVariables"].items())]
        parts.append("Session variables\n\n" + table(["Variable", "Value"], rows))

    if facts["homeValues"]:
        rows = [[format_value(f"rokokol.{name}"), format_value(value)] for name, value in sorted(facts["homeValues"].items())]
        parts.append("Home Manager options\n\n" + table(["Option", "Value"], rows))

    return "\n\n".join(parts)


def inject(text, marker, rendered):
    """Replace the content of a generated block, keeping the prose around it"""
    start = START.format(marker=marker)
    if start not in text:
        raise MarkerMissing(f"no marker {start}")
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


def option_page(names, rows, files):
    """One group of options: a column per host that has it, and the file that declares it"""
    header = ["Option", *names, "Description"]
    return table(header, rows) + "\n\nDeclared in: " + ", ".join(repo_link(name) for name in files)


def option_pages(facts):
    """The generated blocks of the option pages, keyed by the page path"""
    by_host = {name: group_options(cfg["options"]) for name, cfg in facts["hosts"].items()}
    groups = sorted({group for groups in by_host.values() for group in groups})
    pages = {}
    for group in groups:
        names = [name for name in by_host if group in by_host[name]]
        order = []
        for host in names:
            order += [option["name"] for option in by_host[host][group] if option["name"] not in order]
        rows = []
        for name in order:
            found = {host: next((item for item in by_host[host][group] if item["name"] == name), None) for host in names}
            values = [format_value(found[host]["value"]) if found[host] else "—" for host in names]
            described = next((item["description"] for item in found.values() if item), None)
            rows.append([format_value(name), *values, described or "—"])
        files = sorted({declaration for host in names for option in by_host[host][group] for declaration in option["declarations"]})
        pages[DOCS / "options" / f"{group}.md"] = (f"option {group}", option_page(names, rows, files))
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


def to_scroll_tables(html):
    """A facts table can be wider than the page, and a table that overflows takes the whole layout
    with it, so each one gets a box that scrolls on its own"""
    return html.replace("<table>", '<div class="table-wrap"><table>').replace("</table>", "</table></div>")


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
    "hosts": "Hosts",
    "options": "Options",
    "modules": "Modules",
    "guides": "Guides",
    ".": "Reference",
}

SHELL = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} — huix</title>
<link rel="icon" type="image/jpeg" href="{root}assets/{favicon}">
<script>
  try {{
    const asked = new URLSearchParams(location.search).get("theme")
    const stored = localStorage.getItem("huix-theme")
    const chosen = asked === "light" || asked === "dark" ? asked : stored
    if (chosen === "light" || chosen === "dark") document.documentElement.dataset.theme = chosen
  }} catch {{}}
</script>
<link rel="stylesheet" href="{root}assets/vendor/ddlc/ddlc-tokens.css">
<link rel="stylesheet" href="{root}assets/vendor/ddlc/ddlc-ui.css">
<link rel="stylesheet" href="{root}assets/vendor/ddlc/ddlc-report.css">
<link rel="stylesheet" href="{root}assets/site.css?v={stamp}">
<script type="module" src="{root}assets/site.js?v={stamp}"></script>
</head>
<body>
<canvas class="cloud" aria-hidden="true"></canvas>
<header class="top"><div class="wrap top-inner">
<a class="brand" href="{root}index.html">huix <span class="tagline">the configuration and what runs on it</span></a>
<button class="icon-button" data-theme-toggle type="button"><svg viewBox="0 0 8 8" width="16" height="16" aria-hidden="true"><path d="" fill-rule="evenodd"></path></svg></button>
<a class="icon-button" href="https://github.com/rokokol/huix" aria-label="huix on GitHub"><span class="github-icon" aria-hidden="true"></span></a>
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


def home_page(repo, stamp):
    return (repo / "site" / "home.html").read_text(encoding="utf-8").replace("__STAMP__", stamp)


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
    # A rebuilt stylesheet must reach the reader rather than an hour-old cached copy, so the
    # links carry a digest of the file they point at
    stamp = hashlib.sha256((assets / "site.css").read_bytes()).hexdigest()[:8]
    # The pictures of the corpus live beside it, in docs/img, as the pictures of a README live
    # beside the README
    pictures = repo / DOCS / "img"
    if pictures.is_dir():
        shutil.copytree(pictures, out / "img", dirs_exist_ok=True)
    mark = repo / "assets" / FAVICON
    if mark.is_file():
        shutil.copy2(mark, out / "assets" / FAVICON)

    for relative, meta, body in pages:
        target = relative[: -len(".md")] + ".html"
        root = "../" * (len(Path(relative).parts) - 1)
        main = markdown.markdown(body, extensions=["tables", "fenced_code", "toc", "sane_lists"])
        page = SHELL.format(
            title=page_label(meta.get("title"), relative),
            root=root,
            favicon=FAVICON,
            stamp=stamp,
            sidebar=sidebar_html(sections, target, root),
            main=f'<article class="prose">{to_scroll_tables(to_figures(to_local_links(to_page_links(main), root)))}</article>',
        )
        destination = out / target
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(page, encoding="utf-8")

    index = ["<h1>huix</h1>", '<article class="prose"><p>The documentation of this configuration: what lives where, what turns it on and why it is arranged so. Every page is assembled from the files of the repository itself.</p>']
    for directory, items in sections:
        name = SECTIONS.get(directory, directory)
        links = "".join(f'<li><a href="{item["path"][: -len(".md")]}.html">{item["label"]}</a></li>' for item in items)
        index.append(f"<h2>{name}</h2><ul>{links}</ul>")
    index.append("</article>")
    (out / "docs.html").write_text(
        SHELL.format(
            title="Documentation",
            root="",
            favicon=FAVICON,
            stamp=stamp,
            sidebar=sidebar_html(sections, "index.html", ""),
            main="".join(index),
        ),
        encoding="utf-8",
    )
    (out / "index.html").write_text(home_page(repo, stamp), encoding="utf-8")
    return len(pages)


def script_files(sources):
    """The scripts a reader calls, which are the ones at the top of scripts/ rather than the
    helpers beside them or the tests of them"""
    return sorted(
        path for path in sources if path.startswith("scripts/") and path.count("/") == 1 and path.endswith((".sh", ".py"))
    )


def help_text(repo, path):
    """What a script prints for --help, with a status that says whether the print happened and,
    when it did not, the last line the script said"""
    runner = ["bash", str(repo / path)] if path.endswith(".sh") else [sys.executable, "-B", str(repo / path)]
    try:
        done = subprocess.run(runner + ["--help"], capture_output=True, text=True, timeout=20, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return {"path": path, "help": "", "ok": False, "reason": ""}
    printed = (done.stdout + done.stderr).strip().replace(f"{repo}/", "")
    reason = printed.splitlines()[-1].strip() if printed else ""
    return {"path": path, "help": printed, "ok": done.returncode == 0 and bool(printed), "reason": reason}


def render_scripts(entries):
    """One section per script: its path, and the help it prints, which is the only description
    that cannot disagree with the script itself"""
    parts = []
    for entry in entries:
        lines = [f"## {repo_link(entry['path'])}"]
        if entry["ok"]:
            lines.append("```\n" + entry["help"].replace("```", "'''") + "\n```")
        elif entry.get("reason"):
            lines.append(f"The script prints no `--help` and stops with: `{entry['reason']}`")
        else:
            lines.append("The script prints no `--help`: run it with no arguments, or read the text above")
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
    parser.add_argument("--strict", action="store_true", help="Fail on a page the corpus lacks")
    args = parser.parse_args(argv)

    if args.command == "site":
        pages = render_site(args.repo, args.repo / args.out, args.repo / "site" / "assets")
        print(f"wrote {pages} pages to {args.out}")
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
                title = f"Host {key}"
            elif kind == "option":
                title = "Top-level options" if key == "rokokol" else f"rokokol.{key} options"
            elif kind == "module":
                title = "Repository root" if key == "." else key
            elif kind == "scripts":
                title = "Scripts"
            else:
                title = "Hyprland keys"
            page.parent.mkdir(parents=True, exist_ok=True)
            page.write_text(scaffold(marker, title, hosts, described), encoding="utf-8")
            print(f"created {path}")
        return 0

    stale = []
    missing = []
    for path, (marker, rendered) in sorted(blocks.items()):
        page = args.repo / path
        if not page.exists():
            print(f"missing page {path}")
            missing.append(str(path))
            continue
        text = page.read_text(encoding="utf-8")
        try:
            updated = inject(text, marker, rendered)
        except MarkerMissing as error:
            print(error)
            missing.append(str(path))
            continue
        if updated != text:
            stale.append(str(path))
            if args.command == "inject":
                page.write_text(updated, encoding="utf-8")
                stale.remove(str(path))
        if args.command == "show":
            print(updated)

    for path in stale:
        print(f"stale {path}")
    # A configuration that gained a module and no page is as broken as a page that lags it, and
    # only a build reads the whole corpus rather than the pages a person remembered to add
    if args.strict and missing:
        return 1
    if args.command == "check" and stale:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
