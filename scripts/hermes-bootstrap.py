#!/usr/bin/env python3
"""Give an empty Hermes state its private documents, and keep the ones that exist"""

import argparse
import os
from pathlib import Path
import shutil
import subprocess

from ruamel.yaml import YAML


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--home", required=True, type=Path)
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

    # The memory limits must hold the documents with room for Hermes to add to them
    yaml = YAML(typ="safe", pure=True)
    yaml.version = (1, 1)
    yaml.default_flow_style = False
    yaml.sort_base_mapping_type_on_output = False
    config = yaml.load(config_path.read_text()) or {}
    memory = config.setdefault("memory", {})
    for key, source in (("user_char_limit", args.user), ("memory_char_limit", args.memory)):
        memory[key] = max(memory.get(key, 0), len(source.read_text()) * 2)
    with config_path.open("w") as handle:
        yaml.dump(config, handle)

    for destination, source in documents.items():
        if destination.exists():
            print("Kept existing document: " + destination.name)
            continue
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)
        destination.chmod(0o600)
        print("Installed private document: " + destination.name)


if __name__ == "__main__":
    main()
