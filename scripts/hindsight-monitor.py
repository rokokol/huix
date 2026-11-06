#!/usr/bin/env python3
"""Export the OpenRouter spend of Hindsight's key and observed rerank model calls"""

import argparse
from datetime import datetime, timedelta, timezone
from decimal import Decimal
import fcntl
import json
import os
from pathlib import Path
import sys
import time
import urllib.error
import urllib.request

# The fields of GET /key, and the metric each becomes. Hindsight runs every model on this key,
# so the counter is its spend as the provider billed it, not a figure derived from tokens
FIELDS = (
    ("usage", "usage_usd"),
    ("usage_daily", "usage_daily_usd"),
    ("usage_weekly", "usage_weekly_usd"),
    ("usage_monthly", "usage_monthly_usd"),
    ("limit", "limit_usd"),
    ("limit_remaining", "limit_remaining_usd"),
)

# A day older than this leaves the counter: the traces behind it are pruned long before, and no
# dashboard reads back this far
KEEP_DAYS = 400


def request_json(url, key):
    request = urllib.request.Request(
        url, headers={"Accept": "application/json", "Authorization": "Bearer " + key}
    )
    with urllib.request.urlopen(request, timeout=15) as response:
        return json.loads(response.read(), parse_float=Decimal)


def request_traces(url, token):
    for _ in range(36):
        try:
            return request_json(url, token)
        except urllib.error.URLError as error:
            if not isinstance(error.reason, ConnectionRefusedError):
                raise
            time.sleep(2)
    return request_json(url, token)


def atomic_write(path, text):
    temporary = path.with_name(path.name + ".tmp")
    with temporary.open("w") as handle:
        handle.write(text)
        handle.flush()
        os.fsync(handle.fileno())
    temporary.replace(path)


def load_state(path):
    return json.loads(path.read_text()) if path.exists() else {}


def save_state(path, state):
    atomic_write(path, json.dumps(state) + "\n")


def rerank_days(state, stats, now):
    """Fold today's rerank count into the day the trace ended on, keeping the largest seen.

    The trace table keeps one day, so the bucket of a finished day is never readable in full
    afterwards: the largest value seen for it stands for it, and the total stays a counter that
    only grows.
    """
    days = state.get("days", {})
    for bucket in stats.get("buckets", []):
        day = str(bucket["time"])[:10]
        days[day] = max(int(days.get(day, 0)), int(bucket["total"]))
    oldest = (now - timedelta(days=KEEP_DAYS)).date().isoformat()
    return {day: count for day, count in days.items() if day >= oldest}


def collect(args):
    lines = []
    spend_read = False
    try:
        data = request_json(args.api + "/key", args.key_file.read_text().strip())["data"]
        for field, metric in FIELDS:
            if data.get(field) is not None:
                lines.append(f"hindsight_spend_key_{metric} {data[field]}\n")
        spend_read = True
    except (OSError, ValueError, KeyError):
        print("The spend counter could not be read; no credential was logged", file=sys.stderr)
    # A counter that cannot be read leaves a zero here, so the dashboard shows a dead watch
    # instead of holding the last value forever
    lines.append(f"hindsight_spend_collect_success {int(spend_read)}\n")

    now = datetime.now(timezone.utc)
    calls_read = False
    state_path = args.state_dir / "rerank-calls.json"
    state = load_state(state_path)
    try:
        token = args.token_file.read_text().strip()
        stats = request_traces(
            f"{args.api_hindsight}/v1/default/banks/{args.bank}/llm-requests/stats"
            "?call_type=rerank&period=1d",
            token,
        )
        state["days"] = rerank_days(state, stats, now)
        save_state(state_path, state)
        calls_read = True
    except (OSError, ValueError, KeyError, TypeError):
        print("The rerank trace count could not be read; no credential was logged", file=sys.stderr)
    # The last total stands when the read fails: a counter that falls back to zero would read as
    # a provider reset and the day's increase would be wrong
    total = sum(state.get("days", {}).values())
    lines.append("# HELP hindsight_rerank_model_calls_total Observed rerank model calls, including errors\n")
    lines.append("# TYPE hindsight_rerank_model_calls_total counter\n")
    lines.append(f"hindsight_rerank_model_calls_total {total}\n")
    lines.append(f"hindsight_rerank_calls_collect_success {int(calls_read)}\n")

    lines.append(
        f"hindsight_spend_collect_timestamp_seconds {int(now.timestamp())}\n"
    )
    atomic_write(args.metrics, "".join(lines))
    return 0 if spend_read and calls_read else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--metrics", required=True, type=Path)
    parser.add_argument("--key-file", required=True, type=Path)
    parser.add_argument("--token-file", required=True, type=Path)
    parser.add_argument("--state-dir", required=True, type=Path)
    parser.add_argument("--bank", required=True)
    parser.add_argument("--api", default="https://openrouter.ai/api/v1")
    parser.add_argument("--api-hindsight", default="http://127.0.0.1:8888")
    args = parser.parse_args()
    args.state_dir.mkdir(parents=True, exist_ok=True)
    with (args.state_dir / "lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            return collect(args)
        except (OSError, ValueError, KeyError):
            print("Hindsight monitor failed; no credential values were logged", file=sys.stderr)
            return 1


if __name__ == "__main__":
    sys.exit(main())
