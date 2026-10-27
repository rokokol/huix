import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from ruamel.yaml import YAML


script = Path(__file__).parents[1] / "hermes-seed-config.py"
yaml = YAML(typ="safe", pure=True)


def seed(directory, seed_values, config_text):
    seed_path = directory / "seed.json"
    config_path = directory / "config.yaml"
    seed_path.write_text(json.dumps(seed_values))
    if config_text is not None:
        config_path.write_text(config_text)
    subprocess.run([sys.executable, "-B", str(script), str(seed_path), str(config_path)], check=True)
    return yaml.load(config_path.read_text())


class SeedConfigTest(unittest.TestCase):
    def test_adds_missing_keys_and_keeps_runtime_edits(self):
        values = {
            "mcp_servers": {"dav": {"command": "dav", "enabled": True}, "mail": {"command": "mail"}},
            "memory": {"provider": "builtin", "nudge_interval": 10},
        }
        existing = "mcp_servers:\n  dav:\n    command: dav\n    enabled: false\nmemory:\n  nudge_interval: 3\nmodel: x\n"
        with tempfile.TemporaryDirectory() as directory:
            result = seed(Path(directory), values, existing)
        self.assertFalse(result["mcp_servers"]["dav"]["enabled"])
        self.assertEqual(result["mcp_servers"]["mail"], {"command": "mail"})
        self.assertEqual(result["memory"], {"nudge_interval": 3, "provider": "builtin"})
        self.assertEqual(result["model"], "x")

    def test_read_only_config_in_a_writable_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "config.yaml"
            config.write_text("model: x\n")
            config.chmod(0o440)
            result = seed(Path(directory), {"memory": {"provider": "builtin"}}, None)
            self.assertEqual(result, {"model": "x", "memory": {"provider": "builtin"}})
            self.assertEqual(config.stat().st_mode & 0o777, 0o440)

    def test_complete_config_is_left_byte_for_byte(self):
        existing = "memory:\n  provider: builtin  # set by hand\n"
        with tempfile.TemporaryDirectory() as directory:
            seed(Path(directory), {"memory": {"provider": "other"}}, existing)
            self.assertEqual((Path(directory) / "config.yaml").read_text(), existing)

    def test_empty_config_takes_the_whole_seed(self):
        values = {"curator": {"consolidate": True}}
        with tempfile.TemporaryDirectory() as directory:
            self.assertEqual(seed(Path(directory), values, ""), values)


if __name__ == "__main__":
    unittest.main()
