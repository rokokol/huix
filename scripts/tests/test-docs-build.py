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


if __name__ == "__main__":
    unittest.main()
