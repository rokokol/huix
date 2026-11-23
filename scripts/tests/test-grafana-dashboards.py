"""Check provisioned dashboard structure and the requested visual encodings"""

import json
from pathlib import Path
import sys
import unittest


MANIFEST = json.loads(Path(sys.argv.pop(1)).read_text())


def load_dashboards():
    dashboards = {}
    for provider in MANIFEST["providers"]:
        folder = provider.get("folder", "")
        for path in Path(provider["options"]["path"]).glob("*.json"):
            dashboard = json.loads(path.read_text())
            uid = dashboard["uid"]
            if uid in dashboards:
                raise AssertionError(f"Duplicate dashboard UID: {uid}")
            dashboards[uid] = (folder, dashboard)
    return dashboards


DASHBOARDS = load_dashboards()


def panel(dashboard, title):
    matches = [item for item in dashboard["panels"] if item.get("title") == title]
    if len(matches) != 1:
        raise AssertionError(f"Expected one panel named {title}, found {len(matches)}")
    return matches[0]


class DashboardsTest(unittest.TestCase):
    def test_folders_and_host_uids(self):
        for host in MANIFEST["hosts"]:
            folder, dashboard = DASHBOARDS[host]
            self.assertEqual(folder, "Hosts")
            self.assertEqual(dashboard["title"], host)
            self.assertIn("host", dashboard["tags"])
        for uid in ("hermes", "hindsight", "ai-spend"):
            self.assertEqual(DASHBOARDS[uid][0], "AI")
        for uid in ("mail", "vpn"):
            self.assertEqual(DASHBOARDS[uid][0], "Services")
        self.assertNotIn("guards", DASHBOARDS)
        self.assertNotIn("hosts", DASHBOARDS)

    def test_every_panel_has_a_description_and_dashboard_has_tags(self):
        for uid, (_, dashboard) in DASHBOARDS.items():
            with self.subTest(dashboard=uid):
                self.assertTrue(dashboard.get("tags"), uid)
                for item in dashboard["panels"]:
                    if item["type"] != "row":
                        self.assertTrue(item.get("description"), f'{uid}: {item.get("title")}')
                        self.assertNotIn("description", item.get("options", {}))

    def test_panels_do_not_overlap(self):
        for uid, (_, dashboard) in DASHBOARDS.items():
            panels = dashboard["panels"]
            for index, left in enumerate(panels):
                a = left["gridPos"]
                for right in panels[index + 1:]:
                    b = right["gridPos"]
                    overlap = (a["x"] < b["x"] + b["w"] and b["x"] < a["x"] + a["w"]
                               and a["y"] < b["y"] + b["h"] and b["y"] < a["y"] + a["h"])
                    self.assertFalse(overlap, f'{uid}: {left["title"]} overlaps {right["title"]}')

    def test_discrete_series_use_bars(self):
        names = {
            "hermes": ["Active agents"],
            "hindsight": ["Requests waiting for a DB connection"],
            "mail": ["Queue history", "Messages accepted per hour", "Deliveries per hour",
                     "rspamd actions per hour", "SMTP rejections per hour", "Logins per hour",
                     "fail2ban bans per hour", "Report failures per day", "Collector cursor gaps per day"],
            "vpn": ["Clients online history", "Unit restarts per hour", "Established sockets without a timer",
                    "fail2ban failed attempts per hour", "fail2ban bans per hour", "Packets the firewall dropped per hour"],
        }
        for uid, titles in names.items():
            dashboard = DASHBOARDS[uid][1]
            for title in titles:
                with self.subTest(dashboard=uid, panel=title):
                    custom = panel(dashboard, title)["fieldConfig"]["defaults"]["custom"]
                    self.assertEqual(custom.get("drawStyle"), "bars")

    def test_vpn_traffic_totals_show_each_identity_and_period(self):
        dashboard = DASHBOARDS["vpn"][1]
        for identity in ("inbound", "client"):
            with self.subTest(identity=identity):
                totals = panel(dashboard, f"Traffic totals by {identity}")
                self.assertEqual(totals["type"], "table")
                self.assertEqual(totals["fieldConfig"]["defaults"]["unit"], "bytes")
                target, = totals["targets"]
                self.assertTrue(target["instant"])
                self.assertFalse(target["range"])
                self.assertIn(f"vpn_{identity}_traffic_bytes_total", target["expr"])
                self.assertNotIn("topk(", target["expr"])
                organize = next(t["options"] for t in totals["transformations"] if t["id"] == "organize")
                self.assertTrue({identity, "Total", "Last 30 days", "Last 7 days", "Last 24 hours"}
                                <= organize["indexByName"].keys())

    def test_host_panels_are_scoped_and_station_has_shared_checks(self):
        for host in MANIFEST["hosts"]:
            dashboard = DASHBOARDS[host][1]
            self.assertIn(f'host="{host}"', panel(dashboard, "Failed units")["targets"][0]["expr"])
            self.assertIn("max_over_time", panel(dashboard, "Unit state history")["targets"][0]["expr"])
            self.assertNotIn("Time since the last push", [item["title"] for item in dashboard["panels"]])
        station = DASHBOARDS[MANIFEST["station"]][1]
        for title in ("Age of the newest backup", "Free space for backups", "Peers", "Open problems"):
            panel(station, title)


if __name__ == "__main__":
    unittest.main()
