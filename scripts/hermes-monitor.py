#!/usr/bin/env python3
"""Export Hermes usage and OpenRouter budgets, and report session spend thresholds"""

import argparse
from collections import Counter
from datetime import datetime, timezone
from decimal import Decimal, ROUND_FLOOR
import fcntl
import json
import os
from pathlib import Path
import sqlite3
import sys
import urllib.request


def money(value):
    result = Decimal(str(value or 0))
    if not result.is_finite() or result < 0:
        raise ValueError("Invalid cost value")
    return result


def crossed_threshold(cost, previous, step):
    if not step.is_finite() or step <= 0:
        raise ValueError("The notification step must be positive")
    bucket = int((cost / step).to_integral_value(rounding=ROUND_FLOOR))
    return bucket if bucket > previous else None


def recorded_cost(row):
    actual = row["actual_cost_usd"]
    estimated = actual is None or row["cost_status"] in {"mixed", "partial", "estimated"}
    return money(row["estimated_cost_usd"] if estimated else actual), estimated


def read_sessions(path):
    with sqlite3.connect(path.resolve().as_uri() + "?mode=ro", uri=True, timeout=5) as db:
        db.execute("PRAGMA query_only = ON")
        db.row_factory = sqlite3.Row
        db.execute("BEGIN")
        rows = {row["id"]: dict(row) for row in db.execute(
            "SELECT id, parent_session_id, end_reason, model_config, source, "
            "input_tokens, output_tokens, estimated_cost_usd, actual_cost_usd, cost_status FROM sessions"
        )}
        auxiliary = list(db.execute(
            "SELECT session_id, estimated_cost_usd, actual_cost_usd, cost_status, "
            "input_tokens, output_tokens FROM session_model_usage WHERE task != ''"
        ))

    def root(session_id):
        seen = set()
        while session_id in rows:
            if session_id in seen:
                raise ValueError("Cyclic session lineage")
            seen.add(session_id)
            row = rows[session_id]
            parent = row["parent_session_id"]
            markers = json.loads(row["model_config"] or "{}")
            delegated = markers.get("_delegate_from") == parent and parent is not None
            compressed = parent in rows and rows[parent]["end_reason"] == "compression"
            boundary = any(markers.get(key) == parent for key in ("_reset_from", "_branched_from"))
            if parent not in rows or boundary or not (delegated or compressed):
                break
            session_id = parent
        return session_id

    totals = {}
    for session_id, row in rows.items():
        logical = root(session_id)
        entry = totals.setdefault(logical, {
            "id": logical, "cost": Decimal(0), "estimated": False,
            "source": rows[logical]["source"] or "unknown", "input_tokens": 0, "output_tokens": 0,
        })
        cost, estimated = recorded_cost(row)
        entry["cost"] += cost
        entry["estimated"] |= estimated
        entry["input_tokens"] += row["input_tokens"] or 0
        entry["output_tokens"] += row["output_tokens"] or 0
    for row in auxiliary:
        entry = totals[root(row["session_id"])]
        cost, estimated = recorded_cost(row)
        entry["cost"] += cost
        entry["estimated"] |= estimated
        entry["input_tokens"] += row["input_tokens"] or 0
        entry["output_tokens"] += row["output_tokens"] or 0
    return list(totals.values())


def atomic_write(path, text):
    temporary = path.with_name(path.name + ".tmp")
    with temporary.open("w") as handle:
        handle.write(text)
        handle.flush()
        os.fsync(handle.fileno())
    temporary.replace(path)


def save_state(path, state):
    atomic_write(path, json.dumps(state) + "\n")


def load_state(path):
    return json.loads(path.read_text()) if path.exists() else {}


def notify_sessions(sessions, state, step, balance, send, persist=lambda: None):
    for session in sessions:
        bucket = crossed_threshold(session["cost"], int(state.get(session["id"], 0)), step)
        if bucket is None:
            continue
        label = "Estimated session spend" if session["estimated"] else "Session spend"
        text = (
            f"{label}: ${session['cost']:.2f}\n"
            f"Threshold reached: ${step * bucket:.2f}\n"
            f"Session: {session['id']}\n"
        )
        if balance is None:
            text += "OpenRouter: Balance unavailable"
        else:
            text += f"OpenRouter balance: ${balance['value']:.2f}\nChecked: {balance['checked_at']}"
        send(text)
        state[session["id"]] = bucket
        persist()


def request_json(url, key=None, data=None):
    headers = {"Accept": "application/json"}
    if key:
        headers["Authorization"] = "Bearer " + key
    if data is not None:
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(url, headers=headers, data=data)
    with urllib.request.urlopen(request, timeout=15) as response:
        return json.loads(response.read(), parse_float=Decimal)


def metric(name, value, labels=None):
    suffix = ""
    if labels:
        suffix = "{" + ",".join(f"{key}={json.dumps(str(value))}" for key, value in labels.items()) + "}"
    return f"{name}{suffix} {value}\n"


def collect(args):
    output = []
    errors = []
    now = datetime.now(timezone.utc).isoformat(timespec="seconds")
    sessions = None
    try:
        sessions = read_sessions(args.home / "state.db")
        counts = Counter(item["source"] for item in sessions)
        for source, count in counts.items():
            output.append(metric("hermes_sessions", count, {"source": source}))
        for field in ("input_tokens", "output_tokens", "cost"):
            name = "cost_usd" if field == "cost" else field
            output.append(metric("hermes_" + name, sum(item[field] for item in sessions)))
    except (OSError, sqlite3.Error, ValueError, KeyError):
        errors.append("sessions")
    output.append(metric("hermes_collect_success", int(sessions is not None), {"source": "sessions"}))

    try:
        usage_path = args.home / "skills/.usage.json"
        if usage_path.exists():
            usage = json.loads(usage_path.read_text())
            for name, record in usage.items():
                for action in ("use", "view", "patch"):
                    output.append(metric("hermes_skill_events", int(record.get(action + "_count", 0)), {
                        "skill": name, "action": action,
                    }))
    except (OSError, ValueError, TypeError, AttributeError):
        errors.append("skills")

    key_data = None
    try:
        key_data = request_json(args.api + "/key", args.key_file.read_text().strip())["data"]
        for field in ("usage", "usage_daily", "usage_weekly", "usage_monthly", "limit", "limit_remaining"):
            if key_data.get(field) is not None:
                output.append(metric("openrouter_key_" + field + "_usd", key_data[field]))
        for index, budget in enumerate(key_data.get("budgets", [])):
            labels = {"scope": budget["scope"], "interval": budget.get("reset_interval") or "lifetime", "layer": index}
            output.append(metric("openrouter_budget_remaining_usd", budget["remaining_usd"], labels))
    except (OSError, ValueError, KeyError):
        errors.append("openrouter_key")
    output.append(metric("hermes_collect_success", int(key_data is not None), {"source": "openrouter_key"}))

    balance = None
    if args.management_key_file:
        try:
            credits = request_json(args.api + "/credits", args.management_key_file.read_text().strip())["data"]
            value = Decimal(str(credits["total_credits"])) - Decimal(str(credits["total_usage"]))
            balance = {"value": value, "checked_at": now}
            output.append(metric("openrouter_balance_usd", value))
        except (OSError, ValueError, KeyError):
            errors.append("openrouter_balance")
        output.append(metric("hermes_collect_success", int(balance is not None), {"source": "openrouter_balance"}))

    token = args.bot_token_file.read_text().strip()
    chat = args.chat_id_file.read_text().strip()

    def send(text):
        reply = request_json(
            args.telegram_api + "/bot" + token + "/sendMessage",
            data=json.dumps({"chat_id": chat, "text": text}).encode(),
        )
        if reply.get("ok") is not True or not reply.get("result", {}).get("message_id"):
            raise ValueError("Telegram did not confirm delivery")

    state_path = args.state_dir / "notifications.json"
    state = load_state(state_path)
    step_key = str(args.spend_step)
    delivered = state.setdefault("sessions", {}).setdefault(step_key, {})
    persist = lambda: save_state(state_path, state)
    if sessions is not None:
        notify_sessions(sessions, delivered, args.spend_step, balance, send, persist)

    conditions = {}
    if balance is not None:
        conditions["balance"] = (
            balance["value"] < args.low_balance,
            f"OpenRouter balance is low: ${balance['value']:.2f}\nChecked: {now}",
        )
    if key_data is not None:
        for index, budget in enumerate(key_data.get("budgets", [])):
            limit = Decimal(str(budget["limit_usd"]))
            remaining = Decimal(str(budget["remaining_usd"]))
            conditions[f"budget-{index}"] = (
                limit > 0 and remaining <= limit * Decimal("0.2"),
                f"OpenRouter budget is almost exhausted\nRemaining: ${remaining:.2f} of ${limit:.2f}",
            )
    alerts = state.setdefault("alerts", {})
    for key, (active, text) in conditions.items():
        if active and not alerts.get(key):
            send(text)
        alerts[key] = active
        persist()

    output.append(metric("hermes_collect_timestamp_seconds", int(datetime.now(timezone.utc).timestamp())))
    atomic_write(args.metrics, "".join(output))
    if errors:
        print("Collection failed: " + ", ".join(errors), file=sys.stderr)
        return 1
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--home", required=True, type=Path)
    parser.add_argument("--state-dir", required=True, type=Path)
    parser.add_argument("--metrics", required=True, type=Path)
    parser.add_argument("--key-file", required=True, type=Path)
    parser.add_argument("--management-key-file", type=Path)
    parser.add_argument("--bot-token-file", required=True, type=Path)
    parser.add_argument("--chat-id-file", required=True, type=Path)
    parser.add_argument("--spend-step", default=Decimal("0.50"), type=Decimal)
    parser.add_argument("--low-balance", default=Decimal("5"), type=Decimal)
    parser.add_argument("--api", default="https://openrouter.ai/api/v1")
    parser.add_argument("--telegram-api", default="https://api.telegram.org")
    args = parser.parse_args()
    crossed_threshold(Decimal(0), 0, args.spend_step)
    args.state_dir.mkdir(parents=True, exist_ok=True)
    with (args.state_dir / "lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            return collect(args)
        except (OSError, ValueError, KeyError):
            print("Hermes monitor failed; no credential values were logged", file=sys.stderr)
            return 1


if __name__ == "__main__":
    sys.exit(main())
