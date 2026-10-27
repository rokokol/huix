#!/usr/bin/env python3
"""Add the keys of a JSON seed that a Hermes config.yaml lacks, and keep every key it has"""

import argparse
import json
import os
from pathlib import Path
import stat

from ruamel.yaml import YAML


def fill_missing(current, seed):
    added = []
    for key, value in seed.items():
        if key not in current:
            current[key] = value
            added.append(key)
        elif isinstance(value, dict) and isinstance(current[key], dict):
            added += [key + "." + name for name in fill_missing(current[key], value)]
    return added


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("seed", type=Path, help="JSON file with the initial values")
    parser.add_argument("config", type=Path, help="config.yaml to complete in place")
    args = parser.parse_args()
    # The same YAML dialect as the Hermes module's merge script
    yaml = YAML(typ="safe", pure=True)
    yaml.version = (1, 1)
    yaml.default_flow_style = False
    yaml.sort_base_mapping_type_on_output = False
    current = yaml.load(args.config.read_text()) or {}
    if not isinstance(current, dict):
        parser.error(f"{args.config} is not a mapping")
    added = fill_missing(current, json.loads(args.seed.read_text()))
    if not added:
        return
    # Activation leaves config.yaml read-only to Hermes, so replace it as Hermes does: a new file
    # in the writable directory, with the old file's mode
    temporary = args.config.with_name(args.config.name + ".seed.tmp")
    with temporary.open("w") as handle:
        yaml.dump(current, handle)
    temporary.chmod(stat.S_IMODE(args.config.stat().st_mode))
    os.replace(temporary, args.config)
    print("Seeded Hermes settings: " + ", ".join(added))


if __name__ == "__main__":
    main()
