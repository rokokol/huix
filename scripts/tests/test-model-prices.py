import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    "model_prices", Path(__file__).parents[1] / "model-prices.py"
)
assert spec is not None and spec.loader is not None
monitor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(monitor)


class ModelPricesTest(unittest.TestCase):
    def test_only_configured_endpoints_and_known_prices_are_exported(self):
        response = {"data": {"endpoints": [
            {"tag": "host/fp8", "pricing": {"prompt": "0.000001", "completion": "0.000002", "input_cache_read": "0.0000005"}},
            {"tag": "other/fp8", "pricing": {"prompt": "0.000003"}},
            {"tag": "host/missing", "pricing": {"prompt": None, "completion": "0"}},
        ]}}
        with patch.object(monitor, "fetch", return_value=response):
            output = monitor.collect({"vendor/model": ["host/fp8", "host/missing", "not/listed"]}, "https://example.invalid")
        self.assertIn('model_price_usd_per_million{model="vendor/model",provider="host/fp8",endpoint="host/fp8",kind="input"} 1', output)
        self.assertIn('model_price_usd_per_million{model="vendor/model",provider="host/fp8",endpoint="host/fp8",kind="cache_read"} 0.5', output)
        self.assertNotIn("other/fp8", output)
        self.assertNotIn('provider="host/missing",endpoint="host/missing",kind="input"', output)
        self.assertIn('model_price_endpoint_available{model="vendor/model",provider="not/listed"} 0', output)

    def test_regional_endpoint_keeps_route_available_without_matching_other_tiers(self):
        response = {"data": {"endpoints": [
            {"tag": "host/fp8/us", "pricing": {"prompt": "0.000001"}},
            {"tag": "host/fp8/flex", "pricing": {"prompt": "0.000002"}},
        ]}}
        with patch.object(monitor, "fetch", return_value=response):
            output = monitor.collect({"vendor/model": ["host/fp8"]}, "https://example.invalid")
        self.assertIn('model_price_endpoint_available{model="vendor/model",provider="host/fp8"} 1', output)
        self.assertIn('endpoint="host/fp8/us"', output)
        self.assertNotIn('endpoint="host/fp8/flex"', output)

    def test_a_failed_model_does_not_report_zero_prices(self):
        with patch.object(monitor, "fetch", side_effect=OSError("unreachable")):
            output = monitor.collect({"vendor/model": ["host/fp8"]}, "https://example.invalid")
        self.assertIn('model_price_fetch_success{model="vendor/model"} 0', output)
        self.assertIn('model_price_route_configured{model="vendor/model",provider="host/fp8"} 1', output)
        self.assertNotIn("model_price_usd_per_million", output)
        self.assertNotIn("model_price_endpoint_available", output)

    def test_success_with_missing_endpoints_is_not_a_free_price(self):
        with patch.object(monitor, "fetch", return_value={"data": {"endpoints": []}}):
            output = monitor.collect({"vendor/model": ["host/fp8"]}, "https://example.invalid")
        self.assertIn('model_price_fetch_success{model="vendor/model"} 1', output)
        self.assertIn('model_price_endpoint_available{model="vendor/model",provider="host/fp8"} 0', output)
        self.assertNotIn("model_price_usd_per_million", output)

    def test_malformed_endpoint_does_not_look_like_an_absent_provider(self):
        with patch.object(monitor, "fetch", return_value={"data": {"endpoints": [None]}}):
            output = monitor.collect({"vendor/model": ["host/fp8"]}, "https://example.invalid")
        self.assertIn('model_price_fetch_success{model="vendor/model"} 0', output)
        self.assertNotIn("model_price_endpoint_available", output)

    def test_metrics_replace_atomically(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "prices.prom"
            path.write_text("old\n")
            monitor.write_metrics(path, "new\n")
            self.assertEqual(path.read_text(), "new\n")
            self.assertEqual(list(path.parent.iterdir()), [path])


if __name__ == "__main__":
    unittest.main()
