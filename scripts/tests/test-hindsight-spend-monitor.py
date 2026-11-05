import importlib.util
from decimal import Decimal
from pathlib import Path
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    "hindsight_spend_monitor", Path(__file__).parents[1] / "hindsight-spend-monitor.py"
)
assert spec is not None and spec.loader is not None
monitor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(monitor)


class MonitorTest(unittest.TestCase):
    def args(self, root):
        credential = root / "key"
        credential.write_text("test")
        return SimpleNamespace(
            metrics=root / "metrics.prom",
            key_file=credential,
            api="https://openrouter.invalid",
        )

    def test_collect_exports_the_counter_of_that_key_alone(self):
        with tempfile.TemporaryDirectory() as directory:
            args = self.args(Path(directory))
            payload = {
                "data": {
                    "usage": Decimal("0.000032"),
                    "usage_daily": Decimal("0.000032"),
                    "usage_monthly": Decimal("0.000032"),
                    "limit": None,
                    "limit_remaining": None,
                }
            }
            with patch.object(monitor, "request_json", return_value=payload):
                self.assertEqual(monitor.collect(args), 0)
            text = args.metrics.read_text()
            self.assertIn("hindsight_spend_key_usage_usd 0.000032\n", text)
            self.assertIn("hindsight_spend_key_usage_daily_usd 0.000032\n", text)
            self.assertIn("hindsight_spend_key_usage_monthly_usd 0.000032\n", text)
            # An absent field stays absent rather than becoming a zero the dashboard believes
            self.assertNotIn("limit", text)
            self.assertIn("hindsight_spend_collect_success 1\n", text)

    def test_a_counter_that_cannot_be_read_leaves_a_dead_watch(self):
        with tempfile.TemporaryDirectory() as directory:
            args = self.args(Path(directory))
            with patch.object(monitor, "request_json", side_effect=OSError("no network")):
                self.assertEqual(monitor.collect(args), 1)
            text = args.metrics.read_text()
            self.assertEqual(text.count("\n"), 2)
            self.assertIn("hindsight_spend_collect_success 0\n", text)
            self.assertIn("hindsight_spend_collect_timestamp_seconds ", text)


if __name__ == "__main__":
    unittest.main()
