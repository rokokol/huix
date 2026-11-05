#!/usr/bin/env python3
"""Export the OpenRouter spend of the key Hindsight runs on"""

import argparse
from datetime import datetime, timezone
from decimal import Decimal
import json
import os
from pathlib import Path
import sys
import urllib.request

# The fields of GET /key, and the metric each becomes. Hindsight runs every model on this
# key, so the counter is its spend as the provider billed it, not a figure derived from tokens
FIELDS = (
    ("usage", "usage_usd"),
    ("usage_daily", "usage_daily_usd"),
    ("usage_weekly", "usage_weekly_usd"),
    ("usage_monthly", "usage_monthly_usd"),
    ("limit", "limit_usd"),
    ("limit_remaining", "limit_remaining_usd"),
)


def request_json(url, key):
    request = urllib.request.Request(
        url, headers={"Accept": "application/json", "Authorization": "Bearer " + key}
    )
    with urllib.request.urlopen(request, timeout=15) as response:
        return json.loads(response.read(), parse_float=Decimal)


def atomic_write(path, text):
    temporary = path.with_name(path.name + ".tmp")
    with temporary.open("w") as handle:
        handle.write(text)
        handle.flush()
        os.fsync(handle.fileno())
    temporary.replace(path)


def collect(args):
    lines = []
    read = False
    try:
        data = request_json(args.api + "/key", args.key_file.read_text().strip())["data"]
        for field, metric in FIELDS:
            if data.get(field) is not None:
                lines.append(f"hindsight_spend_key_{metric} {data[field]}\n")
        read = True
    except (OSError, ValueError, KeyError):
        print("The spend counter could not be read; no credential was logged", file=sys.stderr)
    # A counter that cannot be read leaves a zero here, so the dashboard shows a dead watch
    # instead of holding the last value forever
    lines.append(f"hindsight_spend_collect_success {int(read)}\n")
    lines.append(
        f"hindsight_spend_collect_timestamp_seconds {int(datetime.now(timezone.utc).timestamp())}\n"
    )
    atomic_write(args.metrics, "".join(lines))
    return 0 if read else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--metrics", required=True, type=Path)
    parser.add_argument("--key-file", required=True, type=Path)
    parser.add_argument("--api", default="https://openrouter.ai/api/v1")
    args = parser.parse_args()
    return collect(args)


if __name__ == "__main__":
    sys.exit(main())
