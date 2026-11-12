#!/usr/bin/env python3
"""Serve the documentation corpus to an agent over MCP, on this machine and without a network"""

import argparse
import json
import math
import re
from collections import Counter
from pathlib import Path
import sys

REPO = "https://github.com/rokokol/huix"
DOCS = Path("docs")
DOCS_PREFIX = str(DOCS)

# A word is a run of letters and digits, and an identifier is kept whole beside its parts, so a
# query for `tailnet-web.sites` finds the page that spells the option out
WORD = re.compile(r"[0-9a-zа-яё][0-9a-zа-яё_.-]*")
SPLIT = re.compile(r"[_.-]+")

# A one-letter word is in every page and carries no signal
MIN_TOKEN = 2

# What BM25 weighs: a longer chunk must not win for being longer, and a term found twice is worth
# more than once, but not twice as much
K1 = 1.2
B = 0.75

SNIPPET_WIDTH = 240
HEADING = re.compile(r"^##\s+(.+)$", re.MULTILINE)


def tokenize(text):
    """The tokens of a text: whole identifiers and the words inside them"""
    tokens = []
    for match in WORD.finditer(text.lower()):
        whole = match.group(0).rstrip(".")
        tokens.append(whole)
        tokens += [part for part in SPLIT.split(whole) if part != whole]
    return [token for token in tokens if len(token) >= MIN_TOKEN]


def parse_front(text):
    """The front matter of a page and the body after it"""
    if not text.startswith("---\n"):
        return {}, text
    end = text.find("\n---\n", 4)
    if end < 0:
        return {}, text
    meta = {}
    for line in text[4:end].splitlines():
        if ":" in line:
            key, value = line.split(":", 1)
            meta[key.strip()] = value.strip()
    return meta, text[end + 5 :]


def load_corpus(root, prefix=DOCS_PREFIX):
    """Every page of the corpus as its path relative to the repository, its front matter and its
    body. The path a reader sees is the one the repository has, so a page opens where it lives"""
    pages = []
    for path in sorted(Path(root).rglob("*.md")):
        meta, body = parse_front(path.read_text(encoding="utf-8"))
        relative = path.relative_to(root)
        pages.append((f"{prefix}/{relative}" if prefix else str(relative), meta, body))
    return pages


def load_readmes(root):
    """The pages of the layers themselves. A README explains what a directory is for, which no
    page of the corpus repeats, so it belongs in the same index"""
    pages = []
    for path in sorted(Path(root).rglob("README.md")):
        if any(part in {"node_modules", "result"} for part in path.parts):
            continue
        body = path.read_text(encoding="utf-8")
        title = next((line.lstrip("# ").strip() for line in body.splitlines() if line.startswith("# ")), path.parent.name)
        pages.append((str(path.relative_to(root)), {"title": title, "kind": "readme"}, body))
    return pages


LINK = re.compile(r"\[([^\]]*)\]\([^)]*\)")
BARE_URL = re.compile(r"https?://\S+")


def plain(text):
    """The text without its links: a URL carries no meaning of its own, and one repeated on every
    page would weigh like a word the whole corpus is about"""
    return BARE_URL.sub("", LINK.sub(r"\1", text))


def chunk_pages(pages):
    """One chunk per section of a page, each carrying the page it belongs to: an answer has to
    cite a page, and a whole page is too much of the context to spend on one hit"""
    chunks = []
    for path, meta, body in pages:
        for title, text in split_sections(plain(body)):
            chunks.append(
                {
                    "path": path,
                    "title": meta.get("title", Path(path).stem),
                    "kind": meta.get("kind", ""),
                    "heading": title,
                    "text": f"{meta.get('title', '')}\n{title}\n{text}".strip(),
                }
            )
    return chunks


def split_sections(body):
    """The sections of a page as (heading, text), the part before the first heading first"""
    matches = list(HEADING.finditer(body))
    if not matches:
        return [("", body.strip())] if body.strip() else []
    sections = []
    intro = body[: matches[0].start()].strip()
    if intro:
        sections.append(("", intro))
    for index, match in enumerate(matches):
        end = matches[index + 1].start() if index + 1 < len(matches) else len(body)
        block = body[match.start() : end]
        sections.append((match.group(1).strip(), block[block.find("\n") :].strip()))
    return sections


class Index:
    """The corpus with the numbers a ranking needs, counted once"""

    def __init__(self, chunks):
        self.chunks = chunks
        self.documents = [Counter(tokenize(chunk["text"])) for chunk in chunks]
        self.lengths = [sum(document.values()) for document in self.documents]
        self.average = sum(self.lengths) / len(self.lengths) if self.lengths else 0
        self.frequency = Counter()
        for document in self.documents:
            self.frequency.update(document.keys())

    def idf(self, token):
        appearances = self.frequency.get(token, 0)
        total = len(self.chunks)
        return math.log(1 + (total - appearances + 0.5) / (appearances + 0.5))

    def search(self, query, limit=8, kind=None):
        """The chunks that answer a query, best first"""
        wanted = tokenize(query)
        if not wanted or limit <= 0:
            return []
        scored = []
        for position, chunk in enumerate(self.chunks):
            if kind and chunk["kind"] != kind:
                continue
            score = 0.0
            for token in set(wanted):
                count = self.documents[position].get(token, 0)
                if not count:
                    continue
                length = self.lengths[position] or 1
                weight = count * (K1 + 1) / (count + K1 * (1 - B + B * length / (self.average or 1)))
                score += self.idf(token) * weight
            if score > 0:
                scored.append((score, position))
        scored.sort(reverse=True)
        return [self.hit(position, score, wanted) for score, position in scored[:limit]]

    def hit(self, position, score, wanted):
        chunk = self.chunks[position]
        return {
            "path": chunk["path"],
            "title": chunk["title"],
            "heading": chunk["heading"],
            "kind": chunk["kind"],
            "score": round(score, 3),
            "snippet": snippet(chunk["text"], wanted),
            "url": f"{REPO}/blob/master/{chunk['path']}",
        }

    def answer(self, query, limit=8, kind=None):
        hits = self.search(query, limit=limit, kind=kind)
        return {"query": query, "indexed": len(self.chunks), "hits": hits}


def snippet(text, wanted):
    """The stretch of a chunk around the first word that was asked for, so a reader sees why the
    chunk came back at all"""
    flat = re.sub(r"\s+", " ", text)
    lowered = flat.lower()
    at = min((lowered.find(token) for token in wanted if lowered.find(token) >= 0), default=0)
    start = max(0, at - SNIPPET_WIDTH // 3)
    end = min(len(flat), start + SNIPPET_WIDTH)
    return ("…" if start else "") + flat[start:end].strip() + ("…" if end < len(flat) else "")


TOOLS = [
    {
        "name": "search_docs",
        "description": (
            "Search the current huix system configuration in its documentation: hosts, options, services "
            "and how they fit together. The index is a snapshot, not live host state. "
            "Offline and read-only. Returns page paths, headings, snippets and links"
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Words to look for; a page holding more of them ranks higher"},
                "limit": {"type": "integer", "minimum": 1, "maximum": 25, "default": 8},
                "kind": {
                    "type": "string",
                    "enum": ["host", "option", "module", "guide", "scripts", "bindings", "readme"],
                    "description": "Keep pages of this kind only",
                },
            },
            "required": ["query"],
        },
    },
    {
        "name": "get_page",
        "description": "Read one page of the documentation whole, by the path a search returned. Read-only and offline",
        "inputSchema": {
            "type": "object",
            "properties": {"path": {"type": "string", "description": "Page path as search_docs returned it"}},
            "required": ["path"],
        },
    },
]


def call_tool(index, root, name, arguments):
    if name == "search_docs":
        query = str(arguments.get("query", ""))
        limit = int(arguments.get("limit", 8))
        kind = arguments.get("kind") or None
        return index.answer(query, limit=min(max(limit, 1), 25), kind=kind)
    if name == "get_page":
        wanted = str(arguments.get("path", ""))
        page = (Path(root) / wanted).resolve()
        if not str(page).startswith(str(Path(root).resolve())) or not page.is_file():
            return {"error": f"no page {wanted}"}
        meta, body = parse_front(page.read_text(encoding="utf-8"))
        return {"path": wanted, "title": meta.get("title", page.stem), "kind": meta.get("kind", ""), "text": body}
    raise ValueError(f"unknown tool: {name}")


def answer(message):
    """One JSON-RPC message of the MCP protocol, answered"""
    method = message.get("method")
    if method == "initialize":
        return {
            "protocolVersion": message.get("params", {}).get("protocolVersion", "2025-06-18"),
            "capabilities": {"tools": {}},
            "serverInfo": {"name": "actual_system_docs", "version": "0.1.0"},
        }
    if method == "tools/list":
        return {"tools": TOOLS}
    if method == "ping":
        return {}
    return None


def serve(index, root, stream):
    """Answer JSON-RPC messages from the stream until it ends"""
    for line in stream:
        line = line.strip()
        if not line:
            continue
        message = json.loads(line)
        method = message.get("method")
        identifier = message.get("id")
        if method == "tools/call":
            name = message.get("params", {}).get("name", "")
            arguments = message.get("params", {}).get("arguments", {})
            try:
                result = call_tool(index, root, name, arguments)
                content = [{"type": "text", "text": json.dumps(result, ensure_ascii=False)}]
            except (OSError, ValueError) as error:
                content = [{"type": "text", "text": str(error)}]
            print(json.dumps({"jsonrpc": "2.0", "id": identifier, "result": {"content": content}}), flush=True)
            continue
        payload = answer(message)
        if payload is None:
            if identifier is None:
                continue
            print(
                json.dumps({"jsonrpc": "2.0", "id": identifier, "error": {"code": -32601, "message": f"no method {method}"}}),
                flush=True,
            )
            continue
        if identifier is not None:
            print(json.dumps({"jsonrpc": "2.0", "id": identifier, "result": payload}), flush=True)


def main(argv):
    parser = argparse.ArgumentParser(description="The documentation of huix over MCP, offline and read-only")
    parser.add_argument("--repo", default=str(Path(__file__).resolve().parent.parent), type=Path)
    parser.add_argument("--corpus", type=Path, help="A corpus directory other than the one of this repository")
    parser.add_argument("--search", help="Search once and print the answer, instead of serving MCP")
    args = parser.parse_args(argv)

    root = Path(args.repo)
    pages = load_corpus(args.corpus, prefix="") if args.corpus else load_corpus(root / DOCS) + load_readmes(root)
    index = Index(chunk_pages(pages))
    if args.search:
        print(json.dumps(index.answer(args.search), ensure_ascii=False, indent=2))
        return 0
    serve(index, Path(args.corpus) if args.corpus else root, sys.stdin)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
