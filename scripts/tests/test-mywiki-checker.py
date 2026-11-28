import json
import subprocess
import sys
import unittest
from pathlib import Path

CHECKER = Path(__file__).parents[1] / "mywiki-checker" / "checker.py"
INTERPRETER = Path(sys.argv.pop(1))
CONTEXT = {"property_names": ["aliases", "tags", "up", "prev", "next"], "files": ["02. Zettelkasten/Probe.md"],
           "notes": {}, "before": None, "after": None, "links_before": []}


def run(after, before=None):
    payload = {"version": 1, "operation": "write" if before is None else "update",
               "path": "02. Zettelkasten/Probe.md", "before": before, "after": after, "links": [],
               "vault_context": CONTEXT}
    result = subprocess.run([str(INTERPRETER), "-s", "-P", str(CHECKER)], input=json.dumps(payload),
                            capture_output=True, text=True, timeout=30, check=True)
    return json.loads(result.stdout)


class VaultCheckerTest(unittest.TestCase):
    def test_a_second_h1_is_rejected(self):
        answer = run("---\ncreated: 2026-11-28\n---\n# One\n\n# Two\n")
        self.assertEqual(answer["decision"], "reject")
        self.assertIn("single-h1", answer["message"])

    def test_a_clean_note_is_allowed(self):
        self.assertEqual(run("---\ncreated: 2026-11-28\ntags:\n  - прога\n---\n# Проба\n\nСтрока без точки\n"),
                         {"decision": "allow"})

    def test_a_missing_vault_context_is_named(self):
        payload = {"version": 1, "operation": "write", "path": "02. Zettelkasten/Probe.md", "before": None,
                   "after": "---\ncreated: 2026-11-28\n---\n# Проба\n", "links": []}
        result = subprocess.run([str(INTERPRETER), "-s", "-P", str(CHECKER)], input=json.dumps(payload),
                                capture_output=True, text=True, timeout=30, check=True)
        answer = json.loads(result.stdout)
        self.assertEqual(answer["decision"], "reject")
        self.assertIn("vault_context_properties", answer["message"])


if __name__ == "__main__":
    unittest.main()
