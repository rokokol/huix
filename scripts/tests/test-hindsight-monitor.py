import importlib.util
from decimal import Decimal
from pathlib import Path
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    "hindsight_monitor", Path(__file__).parents[1] / "hindsight-monitor.py"
)
assert spec is not None and spec.loader is not None
monitor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(monitor)


def spend_payload():
    return {
        "data": {
            "usage": Decimal("0.000032"),
            "usage_daily": Decimal("0.000032"),
            "usage_monthly": Decimal("0.000032"),
            "limit": None,
            "limit_remaining": None,
        }
    }


def trace_payload(*buckets):
    return {"buckets": [{"time": day + "T00:00:00+00:00", "total": total} for day, total in buckets]}


class MonitorTest(unittest.TestCase):
    def args(self, root):
        key = root / "key"
        key.write_text("key")
        token = root / "token"
        token.write_text("token")
        state = root / "state"
        state.mkdir()
        return SimpleNamespace(
            metrics=root / "metrics.prom",
            key_file=key,
            token_file=token,
            state_dir=state,
            bank="shared",
            api="https://openrouter.invalid",
            api_hindsight="http://hindsight.invalid",
        )

    def test_collect_exports_the_spend_and_the_paid_reranks(self):
        with tempfile.TemporaryDirectory() as directory:
            args = self.args(Path(directory))
            answers = [spend_payload(), trace_payload(("2026-11-05", 2))]

            def request(url, key=None):
                assert "credential" not in url
                return answers.pop(0)

            with patch.object(monitor, "request_json", side_effect=request):
                self.assertEqual(monitor.collect(args), 0)
            text = args.metrics.read_text()
            self.assertIn("hindsight_spend_key_usage_usd 0.000032\n", text)
            # An absent field stays absent rather than becoming a zero the dashboard believes
            self.assertNotIn("limit", text)
            self.assertIn("hindsight_rerank_paid_calls_total 2\n", text)
            self.assertIn("hindsight_spend_collect_success 1\n", text)
            self.assertIn("hindsight_rerank_calls_collect_success 1\n", text)

    def test_the_counter_follows_a_day_that_grows_and_then_a_new_day(self):
        with tempfile.TemporaryDirectory() as directory:
            args = self.args(Path(directory))
            runs = [
                (spend_payload(), trace_payload(("2026-11-05", 2)), "2"),
                (spend_payload(), trace_payload(("2026-11-05", 5)), "5"),
                (spend_payload(), trace_payload(("2026-11-06", 1)), "6"),
                # The finished day left the trace table, and the count must not fall back
                (spend_payload(), trace_payload(("2026-11-06", 3)), "8"),
            ]

            for spend, traces, expected in runs:
                with patch.object(monitor, "request_json", side_effect=[spend, traces]):
                    self.assertEqual(monitor.collect(args), 0)
                text = args.metrics.read_text()
                self.assertIn(f"hindsight_rerank_paid_calls_total {expected}\n", text)

    def test_a_failed_trace_read_keeps_the_last_total(self):
        with tempfile.TemporaryDirectory() as directory:
            args = self.args(Path(directory))
            with patch.object(
                monitor, "request_json", side_effect=[spend_payload(), trace_payload(("2026-11-05", 4))]
            ):
                self.assertEqual(monitor.collect(args), 0)
            with patch.object(
                monitor, "request_json", side_effect=[spend_payload(), OSError("no network")]
            ):
                self.assertEqual(monitor.collect(args), 1)
            text = args.metrics.read_text()
            self.assertIn("hindsight_rerank_paid_calls_total 4\n", text)
            self.assertIn("hindsight_rerank_calls_collect_success 0\n", text)
            self.assertIn("hindsight_spend_collect_success 1\n", text)

    def test_a_failed_spend_read_still_reports_the_calls(self):
        with tempfile.TemporaryDirectory() as directory:
            args = self.args(Path(directory))
            with patch.object(
                monitor, "request_json", side_effect=[OSError("no network"), trace_payload(("2026-11-05", 4))]
            ):
                self.assertEqual(monitor.collect(args), 1)
            text = args.metrics.read_text()
            self.assertIn("hindsight_spend_collect_success 0\n", text)
            self.assertIn("hindsight_rerank_paid_calls_total 4\n", text)


if __name__ == "__main__":
    unittest.main()
