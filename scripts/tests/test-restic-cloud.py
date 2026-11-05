import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    "restic_cloud", Path(__file__).parents[1] / "restic-cloud.py"
)
assert spec is not None and spec.loader is not None
cloud = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cloud)


class CloudTest(unittest.TestCase):
    def setUp(self):
        self.work = tempfile.TemporaryDirectory()
        self.addCleanup(self.work.cleanup)
        self.root = Path(self.work.name)
        self.source = self.root / "source"
        self.remote = self.root / "remote"
        self.source.mkdir()
        self.remote.mkdir()
        config = self.root / "rclone.conf"
        config.touch(mode=0o600)
        self.runner = cloud.Rclone(config)
        self.state = self.root / "success.json"
        self.expected = {"node", "station"}
        for repo in self.expected:
            (self.source / repo / "snapshots").mkdir(parents=True)
            (self.source / repo / "keys").mkdir()
            (self.source / repo / "locks").mkdir()
            (self.source / repo / "config").write_bytes(b"config")
            (self.source / repo / "keys" / ("a" * 64)).write_bytes(b"encrypted-key")
            (self.source / repo / "snapshots" / ("b" * 64)).write_bytes(b"encrypted-snapshot")

    def run_mirror(self):
        return cloud.mirror(self.source, str(self.remote), self.expected,
                            self.runner, self.state)

    def test_real_local_transport_copies_all_repositories_and_records_success(self):
        (self.source / ".htpasswd").write_text("never upload")
        self.run_mirror()
        for repo in self.expected:
            self.assertEqual((self.remote / repo / "config").read_bytes(), b"config")
        self.assertFalse((self.remote / ".htpasswd").exists())
        self.assertEqual(json.loads(self.state.read_text())["repositories"], sorted(self.expected))

    def test_active_lock_and_missing_repository_refuse_before_remote_changes(self):
        lock = self.source / "node" / "locks" / ("c" * 64)
        lock.write_bytes(b"encrypted-lock")
        with self.assertRaises(cloud.Error):
            self.run_mirror()
        self.assertEqual(list(self.remote.iterdir()), [])
        lock.unlink()
        with self.assertRaises(cloud.Error):
            cloud.mirror(self.source, str(self.remote), {"absent"}, self.runner, self.state)
        self.assertEqual(list(self.remote.iterdir()), [])

    def test_previous_snapshot_survives_upload_failure(self):
        self.run_mirror()
        old = "node/snapshots/" + "b" * 64
        (self.source / old).unlink()
        (self.source / "node" / "snapshots" / ("c" * 64)).write_bytes(b"new")
        before = self.state.read_bytes()
        original = self.runner.run

        def fail_upload(*args, **kwargs):
            if args[0] == "copy":
                raise cloud.Error("upload failed")
            return original(*args, **kwargs)

        with patch.object(self.runner, "run", side_effect=fail_upload):
            with self.assertRaises(cloud.Error):
                self.run_mirror()
        self.assertTrue((self.remote / old).exists())
        self.assertEqual(self.state.read_bytes(), before)

    def test_missing_remote_hash_blocks_deletion(self):
        self.run_mirror()
        old = "node/snapshots/" + "b" * 64
        (self.source / old).unlink()
        (self.source / "node" / "snapshots" / ("c" * 64)).write_bytes(b"new")
        original = self.runner.run

        listings = 0

        def no_hash(*args, **kwargs):
            nonlocal listings
            result = original(*args, **kwargs)
            if args[0] == "lsjson":
                listings += 1
                if listings == 2:
                    items = json.loads(result)
                    for item in items:
                        item.pop("Hashes", None)
                    return json.dumps(items)
            return result

        with patch.object(self.runner, "run", side_effect=no_hash):
            with self.assertRaises(cloud.Error):
                self.run_mirror()
        self.assertTrue((self.remote / old).exists())

    def test_success_replaces_old_version_but_not_unrelated_destination(self):
        unrelated = self.root / "unrelated"
        unrelated.write_text("keep")
        self.run_mirror()
        old = self.source / "node" / "snapshots" / ("b" * 64)
        old.unlink()
        new = self.source / "node" / "snapshots" / ("c" * 64)
        new.write_bytes(b"new")
        self.run_mirror()
        self.assertFalse((self.remote / old.relative_to(self.source)).exists())
        self.assertEqual((self.remote / new.relative_to(self.source)).read_bytes(), b"new")
        self.assertEqual(unrelated.read_text(), "keep")

    def test_unknown_remote_contents_and_changed_immutable_file_refuse(self):
        (self.remote / "important.txt").write_text("keep")
        with self.assertRaises(cloud.Error):
            self.run_mirror()
        self.assertEqual((self.remote / "important.txt").read_text(), "keep")
        (self.remote / "important.txt").unlink()
        self.run_mirror()
        (self.source / "node" / "config").write_bytes(b"other-repository")
        with self.assertRaises(cloud.Error):
            self.run_mirror()
        self.assertEqual((self.remote / "node" / "config").read_bytes(), b"config")

    def test_symlink_and_extra_plaintext_source_file_refuse(self):
        (self.source / "node" / "password.txt").write_text("secret")
        with self.assertRaises(cloud.Error):
            self.run_mirror()
        (self.source / "node" / "password.txt").unlink()
        config = self.source / "node" / "config"
        config.unlink()
        config.symlink_to("/etc/passwd")
        with self.assertRaises(cloud.Error):
            self.run_mirror()
        self.assertEqual(list(self.remote.iterdir()), [])

    def test_shared_config_lock_refuses_auth_during_mirror(self):
        with cloud.config_lock(self.runner.config):
            self.assertTrue(self.runner.config.with_name(
                self.runner.config.name + ".drive-backup.lock").is_file())
            with self.assertRaises(cloud.Error):
                with cloud.config_lock(self.runner.config):
                    self.fail("A concurrent config operation acquired the mirror lock")

    def test_duplicate_remote_paths_refuse(self):
        item = {"Path": "node/config", "Size": 6,
                "Hashes": {"sha256": "a" * 64}}
        with patch.object(self.runner, "run", return_value=json.dumps([item, item])):
            with self.assertRaises(cloud.Error):
                cloud.remote_inventory(self.runner, str(self.remote))

    def test_snapshot_selection_sorts_collision_suffixes_numerically(self):
        snapshots = self.root / "snapshots"
        snapshots.mkdir()
        for suffix in ("_9", "_10"):
            (snapshots / ("restic.20261105T0430" + suffix)).mkdir()
        with patch.object(cloud.subprocess, "run") as run:
            run.return_value.stdout = "ro=true\n"
            self.assertEqual(cloud.latest_snapshot(snapshots).name,
                             "restic.20261105T0430_10")
            run.return_value.stdout = "ro=false\n"
            with self.assertRaises(cloud.Error):
                cloud.latest_snapshot(snapshots)

    def test_account_switch_invalidates_success_but_access_token_refresh_does_not(self):
        config = self.runner.config
        destination = "drive-backup:backups/restic"

        def token(refresh, access):
            value = json.dumps({"refresh_token": refresh, "access_token": access})
            config.write_text("[drive-backup]\ntype=drive\ntoken=" + value + "\n")

        token("account-one", "temporary-one")
        cloud.save_state(self.state, {"time": int(cloud.time.time()),
                                     "account": cloud.account_fingerprint(config, destination)})
        cloud.check_age(self.state, 3600, config, destination)
        token("account-one", "temporary-two")
        cloud.check_age(self.state, 3600, config, destination)
        token("account-two", "temporary-three")
        with self.assertRaises(cloud.Error):
            cloud.check_age(self.state, 3600, config, destination)

    def test_heartbeat_is_red_without_success_and_when_stale(self):
        with self.assertRaises(cloud.Error):
            cloud.check_age(self.state, 3600, self.runner.config, str(self.remote))
        self.run_mirror()
        cloud.check_age(self.state, 3600, self.runner.config, str(self.remote))
        data = json.loads(self.state.read_text())
        data["time"] = 1
        self.state.write_text(json.dumps(data))
        with self.assertRaises(cloud.Error):
            cloud.check_age(self.state, 3600, self.runner.config, str(self.remote))


if __name__ == "__main__":
    unittest.main()
