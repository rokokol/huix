import importlib.util
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "grafana-alerts.py"
spec = importlib.util.spec_from_file_location("grafana_alerts", SCRIPT)
assert spec and spec.loader
bridge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge)


def event(status="firing", fingerprint="1234567890abcdef", start="2026-11-01T00:00:00Z"):
    return {
        "status": status,
        "fingerprint": fingerprint,
        "startsAt": start,
        "labels": {"alertname": "Disk forecast", "instance": "station", "huix_resource": "true"},
        "annotations": {"summary": "Disk will fill within seven days"},
    }


class BridgeTests(unittest.TestCase):
    def test_group_lifecycle_and_duplicates(self):
        active = bridge.apply({}, {"alerts": [event(), event(fingerprint="fedcba0987654321")]})
        self.assertEqual(len(bridge.causes(active).splitlines()), 2)
        self.assertEqual(bridge.apply(active, {"alerts": [event()]}), active)
        closed = bridge.apply(active, {"alerts": [event("resolved")]})
        self.assertEqual(len(bridge.causes(closed).splitlines()), 1)
        self.assertIn("fedcba0987654321", bridge.causes(closed))

    def test_late_delivery_cannot_reopen_resolved_instance(self):
        closed = bridge.apply({}, {"alerts": [event("resolved")]})
        self.assertEqual(bridge.apply(closed, {"alerts": [event()]}), closed)
        reopened = bridge.apply(closed, {"alerts": [event(start="2026-11-02T00:00:00Z")]})
        self.assertTrue(bridge.causes(reopened))

    def test_invalid_group_is_atomic(self):
        for invalid in [event("pending"), event(fingerprint="../escape"), {}, {**event(), "labels": {}}]:
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                bridge.apply({}, {"alerts": [event(), invalid]})
        with self.assertRaises(ValueError):
            bridge.apply({}, {"alerts": [], "truncatedAlerts": 2})

    def test_subject_cannot_create_a_second_cause(self):
        alert = event()
        alert["annotations"]["summary"] = "disk\nforged\tentry\rtest"
        state = bridge.apply({}, {"alerts": [alert]})
        self.assertEqual(len(bridge.causes(state).splitlines()), 1)
        self.assertEqual(bridge.causes(state).count("\t"), 1)

    def test_state_survives_restart_and_restores_causes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            state = bridge.apply({}, {"alerts": [event()]})
            bridge.save(root, state)
            self.assertEqual(bridge.restore(root), state)
            (root / "causes").unlink()
            bridge.save(root, bridge.restore(root))
            self.assertEqual((root / "causes").read_text(), bridge.causes(state))


if __name__ == "__main__":
    unittest.main()
