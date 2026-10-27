import importlib.util
from pathlib import Path
import sqlite3
import tempfile
import unittest
from decimal import Decimal


spec = importlib.util.spec_from_file_location(
    "hermes_monitor", Path(__file__).parents[1] / "hermes-monitor.py"
)
assert spec is not None and spec.loader is not None
monitor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(monitor)


def record(sent):
    """A sender that keeps the text of each notice"""
    return lambda text, about=None: sent.append(text)


class MonitorTest(unittest.TestCase):
    def test_threshold_boundaries_and_large_jump(self):
        step = Decimal("0.50")
        self.assertIsNone(monitor.crossed_threshold(Decimal("0.49"), 0, step))
        self.assertEqual(monitor.crossed_threshold(Decimal("0.50"), 0, step), 1)
        self.assertIsNone(monitor.crossed_threshold(Decimal("0.53"), 1, step))
        self.assertEqual(monitor.crossed_threshold(Decimal("2.10"), 1, step), 4)
        self.assertIsNone(monitor.crossed_threshold(Decimal("0.40"), 1, step))

    def test_failed_delivery_does_not_consume_threshold(self):
        state = {}
        session = {"id": "one", "cost": Decimal("0.53"), "estimated": False}

        def reject(_text, _about=None):
            raise RuntimeError("offline")

        with self.assertRaises(RuntimeError):
            monitor.notify_sessions([session], state, Decimal("0.50"), None, reject)
        self.assertEqual(state, {})
        sent = []
        monitor.notify_sessions([session], state, Decimal("0.50"), None, record(sent))
        self.assertEqual(len(sent), 1)
        self.assertIn("Balance unavailable", sent[0])
        monitor.notify_sessions([session], state, Decimal("0.50"), None, record(sent))
        self.assertEqual(len(sent), 1)

    def test_notification_has_account_balance_and_estimate_label(self):
        sent = []
        monitor.notify_sessions(
            [{"id": "two", "cost": Decimal("1.02"), "estimated": True}],
            {},
            Decimal("0.50"),
            {"value": Decimal("18.47"), "checked_at": "2026-10-25T12:00:00+00:00"},
            record(sent),
        )
        self.assertEqual(len(sent), 1)
        self.assertIn("Estimated session spend: $1.02", sent[0])
        self.assertIn("OpenRouter balance: $18.47", sent[0])
        self.assertIn("12:00:00", sent[0])

    def test_spend_notice_follows_the_session_into_its_topic(self):
        def topic(**session):
            return monitor.notice_topic(session, owner_chat="1", reports=5, home=6)
        self.assertEqual(topic(source="telegram", chat_id="1", thread_id="77"), 77)
        self.assertIsNone(topic(source="telegram", chat_id="1", thread_id=None))
        self.assertEqual(topic(source="webhook", chat_id=None, thread_id=None), 5)
        self.assertEqual(topic(source="cron", chat_id=None, thread_id=None), 6)
        self.assertEqual(topic(source="telegram", chat_id="2", thread_id="77"), 5)
        self.assertEqual(monitor.notice_topic(None, owner_chat="1", reports=5, home=6), 5)

    def test_notice_carries_its_session_to_the_sender(self):
        sent = []
        session = {"id": "one", "cost": Decimal("0.53"), "estimated": False, "thread_id": "77"}
        monitor.notify_sessions([session], {}, Decimal("0.50"), None, lambda text, about=None: sent.append(about))
        self.assertEqual(sent, [session])

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
            sent = []
            monitor.notify_sessions(
                [{"id": "one", "cost": Decimal("1.02"), "estimated": False}],
                monitor.load_state(path), Decimal("0.50"), None, record(sent),
            )
            self.assertEqual(sent, [])


if __name__ == "__main__":
    unittest.main()
