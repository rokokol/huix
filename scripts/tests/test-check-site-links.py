import importlib.util
import tempfile
import unittest
from pathlib import Path


spec = importlib.util.spec_from_file_location("links", Path(__file__).parents[1] / "check-site-links.py")
assert spec is not None and spec.loader is not None
links = importlib.util.module_from_spec(spec)
spec.loader.exec_module(links)


class MissingTest(unittest.TestCase):
    def site(self, root, page, body):
        target = Path(root) / page
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(body, encoding="utf-8")
        return Path(root)

    def test_a_link_to_a_page_the_build_wrote_resolves(self):
        with tempfile.TemporaryDirectory() as directory:
            site = self.site(directory, "index.html", '<a href="guides/theme.html">theme</a>')
            self.site(directory, "guides/theme.html", "<p>theme</p>")
            self.assertEqual(links.missing(site), [])

    def test_a_link_to_a_page_the_build_did_not_write_is_named(self):
        with tempfile.TemporaryDirectory() as directory:
            site = self.site(directory, "index.html", '<a href="guides/absent.html">gone</a>')
            self.assertEqual(links.missing(site), [(Path("index.html"), "guides/absent.html")])

    def test_a_link_that_leaves_the_site_is_not_checked(self):
        with tempfile.TemporaryDirectory() as directory:
            body = '<a href="https://example.org/x">out</a><a href="#top">top</a><img src="data:x">'
            site = self.site(directory, "index.html", body)
            self.assertEqual(links.missing(site), [])

    def test_a_cache_stamp_and_a_fragment_do_not_hide_a_missing_file(self):
        with tempfile.TemporaryDirectory() as directory:
            site = self.site(directory, "index.html", '<link href="assets/site.css?v=abc"><a href="x.html#part">x</a>')
            self.assertEqual(
                links.missing(site),
                [(Path("index.html"), "assets/site.css"), (Path("index.html"), "x.html")],
            )

    def test_a_picture_of_a_subdirectory_resolves_against_its_page(self):
        with tempfile.TemporaryDirectory() as directory:
            site = self.site(directory, "nixos/README.html", '<img src="../assets/logo.jpg">')
            (Path(directory) / "assets").mkdir()
            (Path(directory) / "assets" / "logo.jpg").write_bytes(b"x")
            self.assertEqual(links.missing(site), [])


if __name__ == "__main__":
    unittest.main()
