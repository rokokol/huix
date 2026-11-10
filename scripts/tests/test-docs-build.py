import importlib.util
from pathlib import Path
import unittest


spec = importlib.util.spec_from_file_location(
    "docs_build", Path(__file__).parents[1] / "docs-build.py"
)
assert spec is not None and spec.loader is not None
docs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(docs)


def host(**overrides):
    facts = {
        "name": "nixos-pc",
        "system": "x86_64-linux",
        "options": [],
        "homeValues": {},
        "secrets": [],
        "services": [],
        "timers": [],
        "tailnet": {},
        "firewall": {"tcp": [], "udp": []},
        "sessionVariables": {},
    }
    facts.update(overrides)
    return facts


def option(name, value, description=None, declarations=("nixos/services/x.nix",)):
    return {
        "name": name,
        "description": description,
        "type": "boolean",
        "declarations": list(declarations),
        "value": value,
    }


class FormatValueTest(unittest.TestCase):
    def test_a_boolean_reads_as_a_word_rather_than_python(self):
        self.assertEqual(docs.format_value(True), "да")
        self.assertEqual(docs.format_value(False), "нет")

    def test_an_unset_option_leaves_a_dash(self):
        self.assertEqual(docs.format_value(None), "—")

    def test_a_string_is_code_because_it_is_a_value_not_prose(self):
        self.assertEqual(docs.format_value("00:30"), "`00:30`")

    def test_a_list_joins_into_one_cell(self):
        self.assertEqual(docs.format_value([22, 2222]), "`22`, `2222`")

    def test_an_empty_list_is_not_an_empty_cell(self):
        self.assertEqual(docs.format_value([]), "—")

    def test_a_pipe_in_a_string_cannot_break_the_table_it_sits_in(self):
        self.assertEqual(docs.format_value("a|b"), r"`a\|b`")


class OwnUnitsTest(unittest.TestCase):
    sources = {
        "nixos/services/ai/hermes.nix": "systemd.services.hermes-agent = { };\n",
        "home-manager/desktop/sync.nix": "systemd.user.services.syssync = { };\n",
        "nixos/services/system/cron.nix": "systemd.timers.forgejo-dump.timerConfig = { };\n",
    }

    def test_a_unit_this_repository_declares_is_ours(self):
        self.assertTrue(docs.owns_unit("hermes-agent", self.sources))

    def test_a_user_unit_this_repository_declares_is_ours(self):
        self.assertTrue(docs.owns_unit("syssync", self.sources))

    def test_a_timer_this_repository_declares_is_ours(self):
        self.assertTrue(docs.owns_unit("forgejo-dump", self.sources))

    def test_a_unit_upstream_declares_is_not_ours(self):
        self.assertFalse(docs.owns_unit("systemd-journald", self.sources))

    def test_a_name_that_only_appears_as_a_prefix_is_not_ours(self):
        self.assertFalse(docs.owns_unit("hermes", self.sources))

    def test_a_name_with_a_template_suffix_is_not_ours(self):
        self.assertFalse(docs.owns_unit("systemd-fsck@", self.sources))


class InjectTest(unittest.TestCase):
    page = "Вступление\n\n<!-- generated: host nixos-pc -->\nстарое\n<!-- /generated -->\n\nКонец\n"

    def test_the_block_is_replaced_and_the_prose_survives(self):
        out = docs.inject(self.page, "host nixos-pc", "новое")
        self.assertIn("Вступление", out)
        self.assertIn("Конец", out)
        self.assertIn("новое", out)
        self.assertNotIn("старое", out)

    def test_injecting_the_same_content_twice_changes_nothing(self):
        once = docs.inject(self.page, "host nixos-pc", "новое")
        self.assertEqual(docs.inject(once, "host nixos-pc", "новое"), once)

    def test_a_page_without_the_marker_is_an_error_rather_than_a_silent_no_op(self):
        with self.assertRaises(docs.MarkerMissing):
            docs.inject("нет маркера\n", "host nixos-pc", "новое")

    def test_the_marker_of_another_page_is_not_used(self):
        with self.assertRaises(docs.MarkerMissing):
            docs.inject(self.page, "host nixos-station", "новое")


class OptionGroupsTest(unittest.TestCase):
    def test_options_group_by_the_first_segment_after_the_prefix(self):
        groups = docs.group_options(
            [
                option("rokokol.alert-mail.enable", True),
                option("rokokol.alert-mail.digestTime", "06:00"),
                option("rokokol.forgejo.enable", True),
            ]
        )
        self.assertEqual(sorted(groups), ["alert-mail", "forgejo"])
        self.assertEqual(len(groups["alert-mail"]), 2)

    def test_an_option_without_a_second_segment_stands_alone(self):
        groups = docs.group_options([option("rokokol.userName", "rokokol")])
        self.assertEqual(sorted(groups), ["rokokol"])


class HostSectionTest(unittest.TestCase):
    def test_an_enabled_service_appears_and_an_upstream_one_does_not(self):
        sources = {"nixos/a.nix": "systemd.services.hermes-agent = { };\n"}
        text = docs.render_host(host(services=["hermes-agent", "systemd-journald"]), sources)
        self.assertIn("`hermes-agent`", text)
        self.assertNotIn("systemd-journald", text)

    def test_an_empty_section_says_so_instead_of_rendering_nothing(self):
        text = docs.render_host(host(), {})
        self.assertNotIn("| |", text)

    def test_every_tailnet_site_carries_its_port(self):
        text = docs.render_host(host(tailnet={"grafana": {"port": 3200, "lan": True}}), {})
        self.assertIn("`3200`", text)
        self.assertIn("grafana", text)



class FileCommentTest(unittest.TestCase):
    def test_the_comment_after_the_argument_header_is_the_file_comment(self):
        text = "{\n  config,\n  lib,\n}:\n\n# Why the page exists\n# and a second line\nlet\n  x = 1;\nin\n{ }\n"
        self.assertEqual(docs.file_comment(text), "Why the page exists\nand a second line")

    def test_a_module_without_a_comment_has_none(self):
        text = "{\n  config,\n  lib,\n}:\nlet\n  cfg = config.rokokol.x;\nin\n{ }\n"
        self.assertIsNone(docs.file_comment(text))

    def test_a_curried_header_is_skipped_before_the_comment(self):
        text = "{ commonArgs }:\n# One system with its home inside\n{\n  configuration,\n}:\n{ }\n"
        self.assertEqual(docs.file_comment(text), "One system with its home inside")

    def test_an_attribution_above_the_header_is_not_mistaken_for_code(self):
        text = "# SPDX-License-Identifier: MIT\n{ lib }:\n# The body comment\n{ }\n"
        self.assertEqual(docs.file_comment(text), "SPDX-License-Identifier: MIT")

    def test_a_nested_brace_in_the_header_does_not_end_it_early(self):
        text = "{\n  a ? { b = 1; },\n}:\n# After a nested default\n{ }\n"
        self.assertEqual(docs.file_comment(text), "After a nested default")


class ParseBindsTest(unittest.TestCase):
    lua = """
local terminal = "kitty"
hl.bind("SUPER + Q", hl.dsp.exec_cmd(terminal))
hl.bind(
  "SUPER + ALT + K",
  hl.dsp.window.resize({ x = 0, y = -40, relative = true }),
  { repeating = true }
)
-- hl.bind("SUPER + 0", hl.dsp.focus({ workspace = "10" }))
hl.bind("SUPER + F12", hl.dsp.exec_cmd("loginctl lock-session"))
"""

    def test_every_live_bind_is_read(self):
        binds = docs.parse_binds(self.lua)
        self.assertEqual([bind["keys"] for bind in binds], ["SUPER + Q", "SUPER + ALT + K", "SUPER + F12"])

    def test_a_dispatcher_keeps_its_subcommand(self):
        binds = docs.parse_binds(self.lua)
        self.assertEqual(binds[1]["dispatcher"], "window.resize")

    def test_a_local_constant_is_resolved_where_it_is_a_plain_string(self):
        binds = docs.parse_binds(self.lua)
        self.assertEqual(binds[0]["argument"], "kitty")

    def test_a_quoted_argument_survives_with_its_spaces(self):
        binds = docs.parse_binds(self.lua)
        self.assertEqual(binds[2]["argument"], "loginctl lock-session")

    def test_a_bind_inside_a_comment_is_not_a_bind(self):
        binds = docs.parse_binds(self.lua)
        self.assertNotIn("SUPER + 0", [bind["keys"] for bind in binds])

    def test_a_repeating_bind_says_so(self):
        binds = docs.parse_binds(self.lua)
        self.assertTrue(binds[1]["repeating"])
        self.assertFalse(binds[0]["repeating"])

class ModulePageTest(unittest.TestCase):
    def test_a_module_section_names_its_path_and_its_reason(self):
        entries = [
            {
                "path": "nixos/services/ai/hindsight/service.nix",
                "comment": "Shared memory for the agents",
                "options": ["rokokol.hindsight.enable"],
                "units": ["hindsight"],
            }
        ]
        text = docs.render_modules(entries)
        self.assertIn("`nixos/services/ai/hindsight/service.nix`", text)
        self.assertIn("Shared memory for the agents", text)
        self.assertIn("`rokokol.hindsight.enable`", text)
        self.assertIn("`hindsight`", text)

    def test_a_module_without_a_comment_does_not_invent_one(self):
        entries = [{"path": "nixos/x.nix", "comment": None, "options": [], "units": []}]
        text = docs.render_modules(entries)
        self.assertIn("`nixos/x.nix`", text)
        self.assertNotIn("None", text)

    def test_an_option_link_points_at_the_page_of_its_group(self):
        entries = [
            {
                "path": "nixos/services/ai/hindsight/service.nix",
                "comment": None,
                "options": ["rokokol.hindsight.enable"],
                "units": [],
            }
        ]
        text = docs.render_modules(entries)
        self.assertIn("../options/hindsight.md", text)


class BindingsPageTest(unittest.TestCase):
    def test_a_bind_lands_in_the_table_with_its_keys(self):
        text = docs.render_bindings(
            [{"keys": "SUPER + Q", "dispatcher": "exec_cmd", "argument": "kitty", "repeating": False}]
        )
        self.assertIn("`SUPER + Q`", text)
        self.assertIn("`exec_cmd`", text)
        self.assertIn("`kitty`", text)

    def test_a_bind_without_an_argument_leaves_a_dash(self):
        text = docs.render_bindings(
            [{"keys": "SUPER + C", "dispatcher": "window.close", "argument": "", "repeating": False}]
        )
        # The whole row is the contract here: an empty argument cell and a dash in the column
        # that says the bind does not repeat are the two ways this row can be wrong
        self.assertIn("| `SUPER + C` | `window.close` | — | — |", text)

    def test_a_repeating_bind_is_marked(self):
        text = docs.render_bindings(
            [{"keys": "SUPER + ALT + K", "dispatcher": "window.resize", "argument": "", "repeating": True}]
        )
        self.assertIn("да", text)


class FrontTest(unittest.TestCase):
    def test_the_front_matter_is_read_and_leaves_the_body(self):
        text = "---\ntitle: Хост nixos-pc\nkind: host\n---\n\n# Заголовок\n"
        meta, body = docs.parse_front(text)
        self.assertEqual(meta["title"], "Хост nixos-pc")
        self.assertEqual(meta["kind"], "host")
        self.assertTrue(body.startswith("\n# Заголовок"))

    def test_a_page_without_front_matter_has_none(self):
        meta, body = docs.parse_front("# Заголовок\n")
        self.assertEqual(meta, {})
        self.assertEqual(body, "# Заголовок\n")


class SiteLinkTest(unittest.TestCase):
    def test_a_link_to_a_neighbouring_page_keeps_its_place(self):
        html = '<a href="../options/hindsight.md">опции</a>'
        self.assertIn('href="../options/hindsight.html"', docs.to_page_links(html))

    def test_a_link_that_leaves_the_corpus_stays_a_markdown_link(self):
        html = '<a href="../../WORKAROUNDS.md">обходные пути</a>'
        self.assertEqual(docs.to_page_links(html), html)


class NavigationTest(unittest.TestCase):
    pages = [
        ("hosts/nixos-pc.md", {"title": "Хост nixos-pc", "kind": "host"}),
        ("bindings.md", {"title": "Клавиши Hyprland", "kind": "bindings"}),
        ("options/hindsight.md", {"title": "Опции rokokol.hindsight", "kind": "option"}),
        ("modules/nixos-desktop.md", {"title": "nixos/desktop", "kind": "module", "dir": "nixos/desktop"}),
    ]

    def test_a_section_holds_the_pages_of_one_directory_in_reading_order(self):
        sections = docs.navigation(self.pages)
        self.assertEqual([name for name, _ in sections], ["hosts", "options", "modules", "."])

    def test_a_page_of_the_root_stands_in_its_own_section(self):
        sections = docs.navigation(self.pages)
        labels = {name: [item["label"] for item in items] for name, items in sections}
        self.assertEqual(labels["."], ["Клавиши Hyprland"])

    def test_a_module_page_is_grouped_by_the_layer_it_describes(self):
        sections = dict(docs.navigation(self.pages))
        self.assertEqual(sections["modules"][0]["group"], "nixos")
        self.assertEqual(sections["modules"][0]["label"], "desktop")


class PageLabelTest(unittest.TestCase):
    def test_a_page_is_named_by_its_title(self):
        self.assertEqual(docs.page_label("Хост nixos-pc", "hosts/nixos-pc.md"), "Хост nixos-pc")

    def test_a_page_without_a_title_falls_back_on_its_slug(self):
        self.assertEqual(docs.page_label(None, "options/hindsight.md"), "hindsight")


class RepoLinkTest(unittest.TestCase):
    def test_a_path_becomes_a_link_to_the_file_in_the_repository(self):
        self.assertEqual(
            docs.repo_link("nixos/services/ai/hindsight/service.nix"),
            "[`nixos/services/ai/hindsight/service.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/ai/hindsight/service.nix)",
        )

    def test_a_host_page_links_the_file_that_configures_it(self):
        sources = {"nixos/configuration-pc.nix": "{ }\n", "nixos/configuration-station.nix": "{ }\n"}
        text = docs.render_host(host(), sources)
        self.assertIn("nixos/configuration-pc.nix", text)
        self.assertIn("blob/master/nixos/configuration-pc.nix", text)

    def test_a_host_page_says_so_when_the_named_file_is_absent(self):
        text = docs.render_host(host(), {})
        self.assertNotIn("blob/master", text)

    def test_a_module_heading_opens_the_module(self):
        entries = [{"path": "nixos/x.nix", "comment": None, "options": [], "units": []}]
        text = docs.render_modules(entries)
        self.assertIn("blob/master/nixos/x.nix", text)


class SidebarTest(unittest.TestCase):
    sections = [
        ("hosts", [{"path": "hosts/nixos-pc.md", "label": "Хост nixos-pc", "group": None}]),
        ("options", [{"path": "options/hindsight.md", "label": "hindsight", "group": None}]),
    ]

    def test_a_sidebar_link_from_a_nested_page_carries_the_step_up(self):
        html = docs.sidebar_html(self.sections, "hosts/nixos-pc.html", "../")
        self.assertIn('href="../options/hindsight.html"', html)

    def test_a_sidebar_link_from_the_root_page_needs_no_prefix(self):
        html = docs.sidebar_html(self.sections, "index.html", "")
        self.assertIn('href="options/hindsight.html"', html)

    def test_the_page_the_reader_is_on_is_marked(self):
        html = docs.sidebar_html(self.sections, "hosts/nixos-pc.html", "../")
        self.assertIn('aria-current="page"', html)


class FigureTest(unittest.TestCase):
    def test_an_image_becomes_a_frame_with_its_alt_text_as_the_caption(self):
        html = '<p><img alt="a screenshot of the waybar" src="../img/waybar.png"></p>'
        out = docs.to_figures(html)
        self.assertIn('<figure class="ddlc-snap">', out)
        self.assertIn('<figcaption>a screenshot of the waybar</figcaption>', out)
        self.assertIn('src="../img/waybar.png"', out)

    def test_two_images_side_by_side_keep_their_order(self):
        html = '<p><img alt="первый" src="a.png"><img alt="второй" src="b.png"></p>'
        out = docs.to_figures(html)
        self.assertEqual(out.count('<figure'), 2)
        self.assertLess(out.index("первый"), out.index("второй"))

    def test_a_paragraph_of_prose_is_left_alone(self):
        html = "<p>обычный абзац</p>"
        self.assertEqual(docs.to_figures(html), html)


class ScriptsTest(unittest.TestCase):
    def test_only_the_scripts_a_reader_calls_are_pages(self):
        sources = {
            "scripts/zoom.sh": "",
            "scripts/drive-backup.py": "",
            "scripts/lib/stub.sh": "",
            "scripts/tests/run.sh": "",
            "nixos/x.nix": "",
        }
        self.assertEqual(docs.script_files(sources), ["scripts/drive-backup.py", "scripts/zoom.sh"])

    def test_a_script_page_carries_the_help_it_prints(self):
        entries = [{"path": "scripts/zoom.sh", "help": "zoom.sh — zoom the screen\n\n  zoom.sh up", "ok": True}]
        text = docs.render_scripts(entries)
        self.assertIn("`scripts/zoom.sh`", text)
        self.assertIn("zoom.sh up", text)

    def test_a_script_that_will_not_print_help_says_so_instead_of_an_empty_block(self):
        entries = [{"path": "scripts/broken.sh", "help": "", "ok": False}]
        text = docs.render_scripts(entries)
        self.assertIn("не печатает `--help`", text)

    def test_the_reason_a_script_cannot_print_help_is_shown_beside_the_refusal(self):
        entries = [
            {
                "path": "scripts/needy.py",
                "help": "",
                "ok": False,
                "reason": "ModuleNotFoundError: No module named 'pathspec'",
            }
        ]
        text = docs.render_scripts(entries)
        self.assertIn("No module named 'pathspec'", text)


if __name__ == "__main__":
    unittest.main()
