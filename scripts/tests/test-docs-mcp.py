import importlib.util
from pathlib import Path
import tempfile
import unittest


spec = importlib.util.spec_from_file_location("docs_mcp", Path(__file__).parents[1] / "docs-mcp.py")
assert spec is not None and spec.loader is not None
mcp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mcp)


PAGES = [
    (
        "options/hindsight.md",
        {"title": "rokokol.hindsight options", "kind": "option"},
        "# rokokol.hindsight options\n\n## Port\n\nThe API listens on `8888` and the tailnet port is `8788`\n\n## Pool\n\nFive connections stay open\n",
    ),
    (
        "guides/theme.md",
        {"title": "Switch the light and dark theme", "kind": "guide"},
        "# Switch the light and dark theme\n\n## Who owns the choice\n\nThe script owns the theme at runtime and a rebuild never overwrites it\n",
    ),
]


class TokenizeTest(unittest.TestCase):
    def test_an_identifier_is_one_token_and_its_parts_too(self):
        tokens = mcp.tokenize("rokokol.tailnet-web.sites")
        self.assertIn("rokokol.tailnet-web.sites", tokens)
        self.assertIn("tailnet", tokens)

    def test_cyrillic_lowercases_like_latin(self):
        self.assertEqual(mcp.tokenize("Тема"), mcp.tokenize("тема"))

    def test_a_single_letter_carries_no_signal(self):
        self.assertEqual(mcp.tokenize("a b c"), [])


class ChunkTest(unittest.TestCase):
    def test_a_section_becomes_its_own_chunk(self):
        chunks = mcp.chunk_pages(PAGES)
        self.assertEqual([chunk["heading"] for chunk in chunks if chunk["path"].endswith("hindsight.md")], ["", "Port", "Pool"])

    def test_a_chunk_carries_its_page_so_the_answer_can_cite_one(self):
        chunks = mcp.chunk_pages(PAGES)
        self.assertEqual({chunk["path"] for chunk in chunks}, {"options/hindsight.md", "guides/theme.md"})

    def test_the_intro_of_a_page_is_its_own_chunk_even_when_it_has_sections(self):
        chunks = [chunk for chunk in mcp.chunk_pages(PAGES) if chunk["path"].endswith("theme.md")]
        self.assertIn("Switch the light and dark theme", chunks[0]["text"])

    def test_a_heading_that_is_a_link_keeps_its_text_and_loses_its_url(self):
        pages = [("modules/x.md", {"title": "x", "kind": "module"}, "## [`nixos/x.nix`](https://github.com/o/r/blob/master/nixos/x.nix)\n\nBody\n")]
        chunk = mcp.chunk_pages(pages)[0]
        self.assertEqual(chunk["heading"], "`nixos/x.nix`")
        self.assertNotIn("https://", chunk["text"])


class SearchTest(unittest.TestCase):
    def setUp(self):
        self.index = mcp.Index(mcp.chunk_pages(PAGES))

    def test_a_rare_word_beats_one_that_is_everywhere(self):
        hits = self.index.search("port", limit=5)
        self.assertTrue(hits)
        self.assertEqual(hits[0]["path"], "options/hindsight.md")
        self.assertEqual(hits[0]["heading"], "Port")

    def test_a_query_of_no_token_finds_nothing_and_says_how_much_it_looked_at(self):
        answer = self.index.answer("!", limit=5)
        self.assertEqual(answer["hits"], [])
        self.assertEqual(answer["indexed"], len(self.index.chunks))

    def test_a_kind_narrows_the_answer(self):
        answer = self.index.answer("theme", limit=5, kind="option")
        paths = [hit["path"] for hit in answer["hits"]]
        self.assertNotIn("guides/theme.md", paths)

    def test_every_hit_names_a_page_a_reader_can_open(self):
        answer = self.index.answer("theme", limit=5)
        self.assertTrue(answer["hits"][0]["url"].startswith("https://github.com/rokokol/huix/blob/master/"))


class ProtocolTest(unittest.TestCase):
    def test_initialize_identifies_the_server(self):
        result = mcp.answer({"method": "initialize", "params": {}})
        self.assertEqual(result["serverInfo"]["name"], "actual_system_docs")

    def test_a_page_of_a_corpus_without_a_prefix_opens_by_its_own_path(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "hosts").mkdir()
            (root / "hosts" / "nixos-pc.md").write_text(
                "---\ntitle: Host nixos-pc\nkind: host\n---\n\n# Host nixos-pc\n\nBody\n", encoding="utf-8"
            )
            pages = mcp.load_corpus(root, prefix="")
            index = mcp.Index(mcp.chunk_pages(pages))
            found = mcp.call_tool(index, root, "get_page", {"path": pages[0][0]})
        self.assertIn("text", found)
        self.assertEqual(found["title"], "Host nixos-pc")

    def test_a_prefix_joins_without_a_doubled_or_missing_slash(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "bindings.md").write_text("# Bindings\n", encoding="utf-8")
            prefixed = mcp.load_corpus(root, prefix="docs")[0][0]
            bare = mcp.load_corpus(root, prefix="")[0][0]
        self.assertEqual(prefixed, "docs/bindings.md")
        self.assertEqual(bare, "bindings.md")


class SplitSectionsTest(unittest.TestCase):
    def test_every_heading_names_its_own_section(self):
        sections = mcp.split_sections("Intro\n\n## One\n\nA\n\n## Two\n\nB\n")
        self.assertEqual([title for title, _ in sections], ["", "One", "Two"])

    def test_a_page_without_a_heading_is_one_section(self):
        sections = mcp.split_sections("Only text\n")
        self.assertEqual(sections, [("", "Only text")])

    def test_an_empty_page_has_no_sections(self):
        self.assertEqual(mcp.split_sections("\n"), [])


class CorpusTest(unittest.TestCase):
    def test_a_corpus_is_read_from_the_markdown_of_every_page(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "docs"
            (root / "guides").mkdir(parents=True)
            (root / "guides" / "theme.md").write_text(
                "---\ntitle: The theme\nkind: guide\n---\n\n# The theme\n\nText\n", encoding="utf-8"
            )
            pages = mcp.load_corpus(root)
        self.assertEqual(len(pages), 1)
        self.assertEqual(pages[0][1]["title"], "The theme")
        self.assertIn("Text", pages[0][2])


if __name__ == "__main__":
    unittest.main()
