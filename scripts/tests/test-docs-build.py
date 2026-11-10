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


if __name__ == "__main__":
    unittest.main()
