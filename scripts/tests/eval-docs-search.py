#!/usr/bin/env python3
"""Measure how often the documentation search finds the page that answers a question, against a
plain grep of the same corpus. A question set of thirty is small enough to read and large enough
to show whether keywords carry the ranking before anything heavier earns its place"""

import argparse
import importlib.util
import json
import subprocess
import sys
from pathlib import Path

QUESTIONS = Path(__file__).resolve().parent / "docs-search-questions.tsv"
TOP = 5


def load_server(path):
    """The module the MCP server is, without starting it"""
    spec = importlib.util.spec_from_file_location("docs_mcp", path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"cannot read {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def read_questions(path, repo):
    """Each question with the page that answers it; a line naming a page the corpus lacks is a
    broken set rather than a miss, so it stops the run"""
    questions = []
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) != 2:
            raise SystemExit(f"{path}:{number}: a question and one page, tab-separated")
        question, page = parts[0].strip(), parts[1].strip()
        if not (repo / page).is_file():
            raise SystemExit(f"{path}:{number}: {page} is not a page of {repo}")
        questions.append({"question": question, "page": page})
    if not questions:
        raise SystemExit(f"{path}: no questions")
    return questions


def mcp_ranking(index, question, limit=TOP):
    """The pages the documentation search returns, best first, one entry per page"""
    pages = []
    for hit in index.search(question, limit=limit * 4):
        if hit["path"] not in pages:
            pages.append(hit["path"])
    return pages[:limit]


def grep_ranking(repo, question, limit=TOP):
    """The pages a plain case-insensitive grep puts first, by how many times the words occur. The
    count is of occurrences rather than of lines, so a page that repeats a word beats one that
    names it once"""
    words = [word for word in question.split() if len(word.strip("?,.()")) > 2]
    if not words:
        return []
    pattern = "|".join(sorted({word.strip("?,.()") for word in words}, key=len, reverse=True))
    done = subprocess.run(
        ["rg", "--no-messages", "--count-matches", "-i", "-g", "*.md", pattern, "."],
        cwd=repo,
        capture_output=True,
        text=True,
        check=False,
    )
    counted = []
    for line in done.stdout.splitlines():
        path, _, count = line.rpartition(":")
        if not count.isdigit():
            continue
        counted.append((int(count), path.removeprefix("./")))
    counted.sort(key=lambda entry: (-entry[0], entry[1]))
    return [path for _, path in counted[:limit]]


def report(name, questions, rank):
    """The share of questions the ranking answers in its first few entries, and what it missed"""
    misses = []
    for item in questions:
        ranked = rank(item["question"])
        if item["page"] not in ranked:
            misses.append({"question": item["question"], "page": item["page"], "got": ranked})
    hits = len(questions) - len(misses)
    share = hits / len(questions)
    print(f"{name}: recall@{TOP} {hits}/{len(questions)} ({share:.0%})")
    for miss in misses:
        print(f"  missed: {miss['page']}")
        print(f"    question: {miss['question']}")
        print(f"    returned: {', '.join(miss['got']) or 'nothing'}")
    return share


def main(argv):
    parser = argparse.ArgumentParser(description="Score the documentation search against a grep of the same pages")
    parser.add_argument("--repo", default=str(Path(__file__).resolve().parents[2]), type=Path)
    parser.add_argument("--questions", default=QUESTIONS, type=Path)
    parser.add_argument("--min-recall", type=float, help="Exit 1 when the search scores below this share")
    parser.add_argument("--json", action="store_true", help="Print the numbers as JSON")
    args = parser.parse_args(argv)

    repo = args.repo.resolve()
    mcp = load_server(repo / "scripts" / "docs-mcp.py")
    questions = read_questions(args.questions, repo)
    pages = mcp.load_corpus(repo / mcp.DOCS) + mcp.load_readmes(repo)
    index = mcp.Index(mcp.chunk_pages(pages))

    search = report("documentation search", questions, lambda question: mcp_ranking(index, question))
    grep = report("grep", questions, lambda question: grep_ranking(repo, question))
    if args.json:
        print(json.dumps({"questions": len(questions), "search": search, "grep": grep}))
    if args.min_recall is not None and search < args.min_recall:
        print(f"below the expected {args.min_recall:.0%}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
