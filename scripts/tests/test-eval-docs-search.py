import importlib.util
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location("eval_docs", Path(__file__).parent / "eval-docs-search.py")
assert spec is not None and spec.loader is not None
evaluation = importlib.util.module_from_spec(spec)
spec.loader.exec_module(evaluation)


class QuestionsTest(unittest.TestCase):
    def test_a_page_the_corpus_lacks_stops_the_run_rather_than_counting_as_a_miss(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = Path(root) / "questions.tsv"
            path.write_text("A question\tdocs/absent.md\n", encoding="utf-8")
            with self.assertRaises(SystemExit):
                evaluation.read_questions(path, root)

    def test_a_line_without_exactly_two_fields_is_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "docs").mkdir()
            (root / "docs" / "theme.md").write_text("# Theme\n", encoding="utf-8")
            path = Path(root) / "questions.tsv"
            path.write_text("A question with no page\n", encoding="utf-8")
            with self.assertRaises(SystemExit):
                evaluation.read_questions(path, root)


class GrepRankingTest(unittest.TestCase):
    # A count of lines made three occurrences on one line weigh the same as one occurrence, and
    # the baseline number stayed believable while measuring something else
    def test_the_page_that_says_a_word_more_often_comes_first(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "docs").mkdir()
            (root / "docs" / "often.md").write_text("syncthing syncthing syncthing\n", encoding="utf-8")
            (root / "docs" / "once.md").write_text("syncthing\n", encoding="utf-8")
            (root / "docs" / "never.md").write_text("something else\n", encoding="utf-8")
            ranked = evaluation.grep_ranking(root, "How is syncthing configured?", limit=2)
        self.assertEqual(ranked, ["docs/often.md", "docs/once.md"])


if __name__ == "__main__":
    unittest.main()
