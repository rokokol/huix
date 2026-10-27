#!/usr/bin/env python3
"""Give an empty Hermes state its initial settings and private documents, and keep what exists"""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

from hermes_cli.default_soul import DEFAULT_SOUL_MD, is_legacy_template_soul


def is_placeholder(path):
    """True for an empty document or the SOUL.md that Hermes writes on its first start"""
    text = path.read_text(encoding="utf-8-sig")
    return not text.strip() or text == DEFAULT_SOUL_MD or is_legacy_template_soul(text)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--home", required=True, type=Path)
    parser.add_argument("--seed-script", required=True, type=Path)
    parser.add_argument("--initial-settings", required=True, type=Path)
    parser.add_argument("--soul", required=True, type=Path)
    parser.add_argument("--user", required=True, type=Path)
    parser.add_argument("--memory", required=True, type=Path)
    args = parser.parse_args()
    if os.geteuid() == 0:
        parser.error("Run this command as the Hermes user, not as root")
    if subprocess.run(["systemctl", "is-active", "--quiet", "hermes-agent.service"]).returncode == 0:
        parser.error("Stop hermes-agent.service first")
    config_path = args.home / "config.yaml"
    if not config_path.exists():
        parser.error("Hermes state must be mounted and initialized first")
    documents = {
        args.home / "SOUL.md": args.soul,
        args.home / "memories/USER.md": args.user,
        args.home / "memories/MEMORY.md": args.memory,
    }
    for source in documents.values():
        if not source.is_file():
            parser.error(f"Missing private document: {source}")

    # The memory limits must hold the documents with room for Hermes to add to them. The seed
    # script adds only absent keys, so a state that already has settings keeps them
    settings = json.loads(args.initial_settings.read_text())
    memory = settings.setdefault("memory", {})
    for key, source in (("user_char_limit", args.user), ("memory_char_limit", args.memory)):
        memory[key] = max(memory.get(key, 0), len(source.read_text()) * 2)
    with tempfile.NamedTemporaryFile("w", suffix=".json") as handle:
        json.dump(settings, handle)
        handle.flush()
        subprocess.run([sys.executable, str(args.seed_script), handle.name, str(config_path)], check=True)

    for destination, source in documents.items():
        if destination.exists() and not is_placeholder(destination):
            print("Kept existing document: " + destination.name)
            continue
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)
        destination.chmod(0o600)
        print("Installed private document: " + destination.name)


if __name__ == "__main__":
    main()
