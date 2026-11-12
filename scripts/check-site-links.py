#!/usr/bin/env python3
"""A site is one directory of files that point at each other, so a link to a file the build did
not write is a reader's dead end. Every href and src that stays on the site must resolve"""

import argparse
import re
import sys
from pathlib import Path
from urllib.parse import unquote

LINK = re.compile(r'(?:href|src)="([^"]+)"')
ELSEWHERE = ("http://", "https://", "mailto:", "#", "data:", "//")


def targets(text):
    """The addresses a page points at, minus the ones that leave the site and the query strings
    a cache stamp rides on"""
    for address in LINK.findall(text):
        if address.startswith(ELSEWHERE):
            continue
        yield address.split("#")[0].split("?")[0]


def missing(site):
    """Every link of the site whose target the build did not write, as (page, address)"""
    missing = []
    for page in sorted(site.rglob("*.html")):
        for address in targets(page.read_text(encoding="utf-8")):
            if not address:
                continue
            target = (page.parent / unquote(address)).resolve()
            if not target.exists():
                missing.append((page.relative_to(site), address))
    return missing


def main(argv):
    parser = argparse.ArgumentParser(description="Check that every internal link of a built site resolves")
    parser.add_argument("site", type=Path)
    args = parser.parse_args(argv)

    if not args.site.is_dir():
        print(f"check-site-links: {args.site} is not a directory", file=sys.stderr)
        return 2
    problems = missing(args.site)
    for page, address in problems:
        print(f"check-site-links: {page} points at {address}, which the build did not write", file=sys.stderr)
    print(f"check-site-links: {len(list(args.site.rglob('*.html')))} page(s), {len(problems)} broken link(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
