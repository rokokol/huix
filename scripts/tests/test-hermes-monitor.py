import importlib.util
from pathlib import Path
import sqlite3
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch
from decimal import Decimal


spec = importlib.util.spec_from_file_location(
    "hermes_monitor", Path(__file__).parents[1] / "hermes-monitor.py"
)
assert spec is not None and spec.loader is not None
monitor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(monitor)


class MonitorTest(unittest.TestCase):
    def test_collect_keeps_metrics_and_balance_alerts_without_spend_notices(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            credential = root / "credential"
            credential.write_text("test")
            args = SimpleNamespace(
                home=root, state_dir=root, metrics=root / "metrics.prom",
                key_file=credential, bot_token_file=credential, chat_id_file=credential,
                api="https://openrouter.invalid", telegram_api="https://telegram.invalid",
                telegram_thread_id=5, low_balance=Decimal("5"),
            )
            sessions = [{"id": "one", "source": "telegram", "cost": Decimal("12"),
                         "input_tokens": 100, "output_tokens": 10, "estimated": False}]
            sent = []
            balance = Decimal("20")

            def request(url, key=None, data=None):
                if url.endswith("/key"):
                    return {"data": {"usage": 12}}
                if url.endswith("/credits"):
                    return {"data": {"total_credits": balance + 12, "total_usage": 12}}
                sent.append(monitor.json.loads(data))
                return {"ok": True, "result": {"message_id": 1}}

            with patch.object(monitor, "read_sessions", return_value=sessions), \
                    patch.object(monitor, "request_json", side_effect=request):
                self.assertEqual(monitor.collect(args), 0)
                self.assertEqual(sent, [])
                self.assertIn("hermes_cost_usd 12\n", args.metrics.read_text())
                balance = Decimal("2")
                self.assertEqual(monitor.collect(args), 0)
                self.assertEqual(len(sent), 1)
                self.assertIn("balance is low", sent[0]["text"])
                self.assertEqual(sent[0]["message_thread_id"], 5)
                self.assertEqual(monitor.collect(args), 0)
                self.assertEqual(len(sent), 1)

    def test_read_only_database_groups_compression_but_not_new_sessions(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "state.db"
            with sqlite3.connect(path) as db:
                db.executescript("""
                    CREATE TABLE sessions (
                        id TEXT, parent_session_id TEXT, end_reason TEXT,
                        model_config TEXT, source TEXT, input_tokens INTEGER,
                        output_tokens INTEGER, estimated_cost_usd REAL,
                        actual_cost_usd REAL, cost_status TEXT,
                        chat_id TEXT, thread_id TEXT
                    );
                    CREATE TABLE session_model_usage (
                        session_id TEXT, task TEXT, estimated_cost_usd REAL,
                        input_tokens INTEGER, output_tokens INTEGER,
                        actual_cost_usd REAL, cost_status TEXT
                    );
                """)
                db.executemany(
                    "INSERT INTO sessions VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                    [
                        ("root", None, "compression", "{}", "telegram", 100, 10, 9, 0.30, "actual", "1", "77"),
                        ("continued", "root", None, "{}", "telegram", 100, 10, 9, 0.25, "actual", "1", "77"),
                        ("new", "root", None, '{"_reset_from":"root"}', "telegram", 1, 1, 0.1, None, "estimated", "1", "78"),
                        ("branch", "root", None, '{"_branched_from":"root"}', "telegram", 1, 1, 0.2, None, "estimated", "1", None),
                        ("delegate", "continued", None, '{"_delegate_from":"continued"}', "tool", 10, 2, 9, 0.05, "actual", None, None),
                    ],
                )
                db.executemany(
                    "INSERT INTO session_model_usage VALUES (?, ?, ?, ?, ?, ?, ?)",
                    [("root", "", 9, 100, 10, 0.30, "actual"), ("continued", "compression", 0.05, 10, 2, 0.03, "actual")],
                )
            result = {item["id"]: item for item in monitor.read_sessions(path)}
            self.assertEqual(set(result), {"root", "new", "branch"})
            self.assertEqual(result["root"]["cost"], Decimal("0.63"))
            self.assertFalse(result["root"]["estimated"])
            self.assertEqual(result["root"]["input_tokens"], 220)
            self.assertEqual(result["new"]["cost"], Decimal("0.1"))
            self.assertEqual(result["branch"]["cost"], Decimal("0.2"))
            self.assertEqual((result["root"]["chat_id"], result["root"]["thread_id"]), ("1", "77"))
            self.assertEqual(result["new"]["thread_id"], "78")

    def test_missing_database_is_not_created(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "missing.db"
            with self.assertRaises(sqlite3.OperationalError):
                monitor.read_sessions(path)
            self.assertFalse(path.exists())

    def test_state_survives_restart(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "notifications.json"
            monitor.save_state(path, {"one": 2})
            self.assertEqual(monitor.load_state(path), {"one": 2})


if __name__ == "__main__":
    unittest.main()
