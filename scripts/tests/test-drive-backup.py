#!/usr/bin/env python3
import contextlib
import hashlib
import importlib.util
import io
import json
import os
import shutil
import stat
import subprocess
import sys
import tarfile
import tempfile
import unittest
from pathlib import Path
from unittest import mock

SCRIPT = Path(__file__).resolve().parents[1] / "drive-backup.py"
spec = importlib.util.spec_from_file_location("drive_backup", SCRIPT)
assert spec is not None and spec.loader is not None
backup = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = backup
spec.loader.exec_module(backup)


class ArchiveTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / "source"
        self.source.mkdir()
        self.remote = self.root / "remote"
        self.remote.mkdir()
        self.config = self.root / "rclone.conf"
        self.config.write_text("[drive-backup]\ntype = local\n")
        self.config.chmod(0o600)
        self.args = [
            "--config",
            str(self.config),
            "archive",
            str(self.source),
            "--to",
            str(self.remote),
        ]
        self.env = mock.patch.dict(
            os.environ, {"XDG_STATE_HOME": str(self.root / "state")}
        )
        self.env.start()
        self.addCleanup(self.env.stop)

    def cli(self, args=None):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = backup.main(self.args if args is None else args)
        return code, out.getvalue(), err.getvalue()

    def tree(self):
        (self.source / ".backupignore").write_text(
            "/root-secret\n*.secret\ncache/\nbuild/*\n!build/keep\ndeep/**/secret\nlink-secret\n"
        )
        for directory in ["nested", "cache", "build", "empty", "deep", "deep/sub"]:
            (self.source / directory).mkdir()
        for name in [
            "root-secret",
            "hidden.secret",
            "cache/file",
            "build/drop",
            "deep/sub/secret",
        ]:
            (self.source / name).write_text("EXCLUDED-SECRET")
        for name in [
            "nested/root-secret",
            "build/keep",
            "visible",
            ".gitignore",
            ".ignore",
        ]:
            (self.source / name).write_text("public")
        (self.source / "visible").chmod(0o751)
        (self.source / "empty").chmod(0o710)
        outside = self.root / "outside"
        outside.write_text("OUTSIDE-SECRET")
        (self.source / "link").symlink_to(outside)
        (self.source / "link-secret").symlink_to(outside)
        (self.source / "dir-link").symlink_to(
            self.source / "cache", target_is_directory=True
        )

    def members(self, archive):
        decoded = subprocess.run(
            ["zstd", "-dc", str(archive)], check=True, capture_output=True
        )
        self.assertNotIn(b"EXCLUDED-SECRET", decoded.stdout)
        self.assertNotIn(b"OUTSIDE-SECRET", decoded.stdout)
        return tarfile.open(fileobj=io.BytesIO(decoded.stdout), mode="r:")

    def test_preview_prints_unicode_names_as_readable_json(self):
        (self.source / "лекция.mkv").write_text("sample")
        code, out, err = self.cli(self.args + ["--dry-run"])
        self.assertEqual(code, 0, err)
        self.assertIn("лекция.mkv", out)
        self.assertIn("\n", out.strip())
        self.assertIn("лекция.mkv", json.loads(out)["included"])

    def test_preview_offline_no_writes_and_git_ignore_rules(self):
        self.tree()
        before = sorted(str(p.relative_to(self.root)) for p in self.root.rglob("*"))
        with mock.patch.object(
            backup.tempfile,
            "TemporaryDirectory",
            side_effect=AssertionError("temp write"),
        ), mock.patch.object(
            backup.Remote, "run", side_effect=AssertionError("remote call")
        ):
            code, out, err = self.cli(self.args + ["--dry-run"])
        self.assertEqual(code, 0, err)
        plan = json.loads(out)
        self.assertIn("nested/root-secret", plan["included"])
        self.assertIn("build/keep", plan["included"])
        self.assertIn("dir-link", plan["included"])
        self.assertIn(".gitignore", plan["included"])
        self.assertIn(".ignore", plan["included"])
        self.assertNotIn("root-secret", plan["included"])
        self.assertNotIn("build/drop", plan["included"])
        self.assertIn("cache/", plan["excluded"])
        self.assertIn("deep/sub/secret", plan["excluded"])
        self.assertNotIn("link-secret", plan["included"])
        self.assertIn(str(self.remote), plan["destination"])
        self.assertEqual(
            before, sorted(str(p.relative_to(self.root)) for p in self.root.rglob("*"))
        )

    def test_real_local_backend_archive_and_replacement_are_isolated(self):
        self.tree()
        unrelated = self.remote / "unrelated.tar.zst"
        unrelated.write_bytes(b"leave this alone")
        code, out, err = self.cli()
        self.assertEqual(code, 0, err)
        result = json.loads(out)
        archives = list(self.remote.rglob("*.tar.zst"))
        archive = next(p for p in archives if p != unrelated)
        with self.members(archive) as tar:
            names = tar.getnames()
            self.assertIn("empty", names)
            self.assertNotIn("root-secret", names)
            self.assertNotIn("cache/file", names)
            self.assertEqual(tar.getmember("visible").mode, 0o751)
            self.assertEqual(tar.getmember("empty").mode, 0o710)
            self.assertTrue(tar.getmember("link").issym())
            self.assertTrue(tar.getmember("dir-link").issym())
            self.assertEqual(tar.getmember("link").linkname, str(self.root / "outside"))
        checksum = archive.with_suffix(archive.suffix + ".sha256")
        expected = hashlib.sha256(archive.read_bytes()).hexdigest()
        self.assertEqual(checksum.read_text(), f"{expected}  {archive.name}\n")
        marker = json.loads(next(self.remote.rglob("*.complete.json")).read_text())
        self.assertEqual(marker["sha256"], expected)
        self.assertEqual(marker["archive"], archive.name)
        self.assertNotIn(str(self.source), json.dumps(marker))
        self.assertIn("generation", result)
        (self.source / "visible").write_text("new data")
        code, _, err = self.cli()
        self.assertEqual(code, 0, err)
        self.assertFalse(archive.exists())
        self.assertEqual(unrelated.read_bytes(), b"leave this alone")
        self.assertEqual(len(list(self.remote.rglob("*.complete.json"))), 1)

    def test_hash_and_upload_failures_preserve_old_generation(self):
        (self.source / "data").write_text("first")
        code, _, err = self.cli()
        self.assertEqual(code, 0, err)
        old = {p: p.read_bytes() for p in self.remote.rglob("*") if p.is_file()}
        (self.source / "data").write_text("second")
        original = backup.Remote.run
        # The local backend runs for real; only the remote SHA-256 reply changes
        for failure in ["missing", "mismatch", "size", "upload", "marker"]:

            def run(remote, *args, failure=failure, **kwargs):
                if args[0] == "cat" and str(args[1]).endswith(".tar.zst"):
                    self.fail("the archive is read back from the remote")
                if args[0] == "copyto" and str(args[1]).startswith("drive-backup:"):
                    self.fail("the archive is downloaded from the remote")
                if failure == "upload" and args[0] == "copyto":
                    raise backup.BackupError("upload failed")
                if (
                    failure == "marker"
                    and args[0] == "copyto"
                    and args[-1].endswith(".complete.json")
                ):
                    raise backup.BackupError("marker failed")
                reply = original(remote, *args, **kwargs)
                if (
                    args[0] == "lsjson"
                    and "--stat" in args
                    and failure in ("missing", "mismatch", "size")
                ):
                    self.assertIn("--hash", args)
                    self.assertIn("--hash-type", args)
                    self.assertIn("SHA-256", args)
                    item = json.loads(reply)
                    if failure == "size":
                        item["Size"] += 1
                    else:
                        item["Hashes"] = (
                            {} if failure == "missing" else {"sha256": "0" * 64}
                        )
                    return json.dumps(item)
                return reply

            with self.subTest(failure=failure), mock.patch.object(
                backup.Remote, "run", run
            ):
                code, out, _ = self.cli()
                self.assertEqual(code, 1)
                self.assertEqual(out, "")
                for path, data in old.items():
                    self.assertEqual(path.read_bytes(), data)

    def test_mutation_during_upload_prevents_new_completion(self):
        path = self.source / "data"
        path.write_text("first")
        code, _, err = self.cli()
        self.assertEqual(code, 0, err)
        old = {p: p.read_bytes() for p in self.remote.rglob("*") if p.is_file()}
        original = backup.Remote.run

        def run(remote, *args, **kwargs):
            if args[0] == "copyto" and args[-1].endswith(".tar.zst"):
                path.write_text("changed during upload")
            return original(remote, *args, **kwargs)

        with mock.patch.object(backup.Remote, "run", run):
            code, out, _ = self.cli()
        self.assertEqual(code, 1)
        self.assertEqual(out, "")
        self.assertEqual(len(list(self.remote.rglob("*.complete.json"))), 1)
        for name, content in old.items():
            self.assertEqual(name.read_bytes(), content)

    def test_mutation_unreadable_and_special_files_fail(self):
        path = self.source / "data"
        path.write_text("before")
        with backup.Source(self.source) as source:
            selection = source.scan()
            path.write_text("after")
            with self.assertRaises(backup.BackupError):
                source.pack(selection, self.root / "bad.tar.zst")
        path.chmod(0)
        code, _, _ = self.cli()
        self.assertEqual(code, 1)
        path.chmod(0o600)
        os.mkfifo(self.source / "fifo")
        code, _, _ = self.cli()
        self.assertEqual(code, 1)
        self.assertEqual(list(self.remote.iterdir()), [])

    def test_ancestor_symlink_swap_cannot_read_outside(self):
        directory = self.source / "directory"
        directory.mkdir()
        (directory / "data").write_text("public")
        outside = self.root / "outside"
        outside.mkdir()
        (outside / "data").write_text("OUTSIDE-SECRET")
        with backup.Source(self.source) as source:
            selection = source.scan()
            directory.rename(self.source / "old")
            directory.symlink_to(outside, target_is_directory=True)
            with self.assertRaises((backup.BackupError, OSError)):
                source.pack(selection, self.root / "bad.tar.zst")
        self.assertEqual(list(self.remote.iterdir()), [])

    def test_ignore_change_between_read_and_scan_fails(self):
        (self.source / ".backupignore").write_text("")
        (self.source / "data").write_text("NEWLY-EXCLUDED-SECRET")
        with backup.Source(self.source) as source:
            original = source.rules

            def changed_rules():
                rules = original()
                (self.source / ".backupignore").write_text("data\n")
                return rules

            with mock.patch.object(source, "rules", changed_rules), self.assertRaises(
                backup.BackupError
            ):
                source.scan()

    def test_file_symlink_swap_fails_before_outside_read(self):
        path = self.source / "data"
        path.write_text("public")
        outside = self.root / "outside"
        outside.write_text("OUTSIDE-SECRET")
        original = os.open

        def swapped(name, flags, *args, **kwargs):
            if name == "data":
                path.unlink()
                path.symlink_to(outside)
            return original(name, flags, *args, **kwargs)

        with backup.Source(self.source) as source:
            selection = source.scan()
            with mock.patch.object(backup.os, "open", swapped), self.assertRaises(
                (backup.BackupError, OSError)
            ):
                source.pack(selection, self.root / "bad.tar.zst")
        self.assertEqual(list(self.remote.iterdir()), [])

    def test_auth_seeds_private_config_without_secret_arguments_or_output(self):
        client = self.root / "client.json"
        client.write_text(
            json.dumps(
                {
                    "installed": {
                        "client_id": "private-id",
                        "client_secret": "private-secret",
                    }
                }
            )
        )
        config = self.root / "oauth" / "rclone.conf"

        # No live OAuth runs here; the rclone boundary supplies only its saved token
        def oauth(args, **kwargs):
            candidate = Path(args[2])
            self.assertEqual(args[3:], ["config", "reconnect", "drive-backup:"])
            self.assertNotEqual(candidate, config)
            self.assertEqual(candidate.parent, config.parent)
            self.assertEqual(stat.S_IMODE(candidate.stat().st_mode), 0o600)
            self.assertEqual(stat.S_IMODE(config.parent.stat().st_mode), 0o700)
            self.assertIn("private-secret", candidate.read_text())
            with candidate.open("a") as stream:
                stream.write('token = {"refresh_token": "private-refresh"}\n')
            return subprocess.CompletedProcess(args, 0)

        with mock.patch.object(backup.sys.stdin, "isatty", return_value=True), \
             mock.patch.object(backup.subprocess, "run", side_effect=oauth):
            code, out, err = self.cli(
                ["--config", str(config), "auth", "--client-secret", str(client)]
            )
        self.assertEqual(code, 0, err)
        self.assertTrue(json.loads(out)["authenticated"])
        self.assertEqual(stat.S_IMODE(config.stat().st_mode), 0o600)
        self.assertIn("private-refresh", config.read_text())
        self.assertEqual(
            sorted(p.name for p in config.parent.iterdir()),
            ["rclone.conf", "rclone.conf.drive-backup.lock"],
        )
        for secret in ("private-id", "private-secret", "private-refresh"):
            self.assertNotIn(secret, out + err)

    def test_headless_auth_is_interactive_and_transactional(self):
        client = self.root / "client.json"
        client.write_text(json.dumps({"installed": {
            "client_id": "test-id", "client_secret": "test-secret"}}))
        config = self.root / "oauth" / "rclone.conf"
        config.parent.mkdir(mode=0o700)
        config.write_text("[drive-backup]\ntype=drive\ntoken=old\n")
        config.chmod(0o600)
        before = config.read_bytes()
        calls = []

        def run(args, **kwargs):
            calls.append(args)
            candidate = Path(args[2])
            self.assertNotEqual(config, candidate)
            self.assertEqual(args[-2:], ["reconnect", "drive-backup:"])
            self.assertNotIn("--auto-confirm", args)
            candidate.write_text(candidate.read_text()
                                 + 'token = {"refresh_token":"new"}\n')
            return subprocess.CompletedProcess(args, 0)

        with mock.patch.object(backup.sys.stdin, "isatty", return_value=True), \
             mock.patch.object(backup.subprocess, "run", side_effect=run):
            code, out, err = self.cli(["--config", str(config), "auth",
                                       "--client-secret", str(client)])
        self.assertEqual(code, 0, err)
        self.assertTrue(json.loads(out)["authenticated"])
        self.assertEqual(len(calls), 1)
        self.assertNotIn("test-secret", " ".join(calls[0]))
        self.assertNotEqual(config.read_bytes(), before)

    def test_auth_malformed_config_does_not_expose_secret(self):
        client = self.root / "client.json"
        client.write_text(
            json.dumps(
                {
                    "installed": {
                        "client_id": "private-id",
                        "client_secret": "private-secret",
                    }
                }
            )
        )
        self.config.write_text("private-secret\n")
        with mock.patch.object(
            backup.Remote, "run", side_effect=AssertionError("live auth")
        ):
            code, out, err = self.cli(
                ["--config", str(self.config), "auth", "--client-secret", str(client)]
            )
        self.assertEqual(code, 1)
        self.assertEqual(out, "")
        self.assertNotIn("private-secret", err)

    def test_lock_refuses_parallel_pair(self):
        with backup.pair_lock("a" * 64), self.assertRaises(backup.BackupError):
            with backup.pair_lock("a" * 64):
                self.fail("parallel lock acquired")

    def test_missing_ignore_is_warned_once_per_archive(self):
        (self.source / "data").write_text("x")
        code, out, err = self.cli()
        self.assertEqual(code, 0, err)
        self.assertEqual(err.count("no root .backupignore"), 1)
        self.assertTrue(json.loads(out)["archive"])

    def test_missing_ignore_warning_and_unknown_flag(self):
        code, out, err = self.cli(self.args + ["--dry-run"])
        self.assertEqual(code, 0, err)
        self.assertIn(".backupignore", err)
        self.assertEqual(json.loads(out)["included"], [])
        with self.assertRaises(SystemExit) as exit_context:
            self.cli(self.args + ["--unknown"])
        self.assertEqual(exit_context.exception.code, 2)

    def test_private_staging_and_remote_marker_last(self):
        (self.source / "data").write_text("private data")
        original = backup.Remote.run
        uploads = []

        def run(remote, *args, **kwargs):
            if args[0] == "copyto":
                path = Path(args[1])
                self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
                self.assertEqual(stat.S_IMODE(path.parent.stat().st_mode), 0o700)
                self.assertFalse(path.is_relative_to(self.source))
                uploads.append(args[-1])
            return original(remote, *args, **kwargs)

        with mock.patch.object(backup.Remote, "run", run):
            code, _, err = self.cli()
        self.assertEqual(code, 0, err)
        self.assertTrue(uploads[-1].endswith(".complete.json"))
        self.assertEqual(len(uploads), 3)

    def test_escaped_trailing_space_is_not_stripped_from_directory_rule(self):
        (self.source / "cache ").mkdir()
        (self.source / "cache " / "secret").write_text("secret")
        (self.source / ".backupignore").write_text("cache\\ /\n")
        (self.source / ".gitignore").write_text("")
        self.assert_git_selection()

    def test_ignore_selection_matches_git_traversal(self):
        self.tree()
        self.assert_git_selection()

    def test_double_star_directory_contents_allow_reinclusion(self):
        self.tree()
        rules = self.source / ".backupignore"
        rules.write_text(rules.read_text().replace("build/*\n", "build/**\n"))
        self.assert_git_selection()
        outside = self.root / "secret-name"
        outside.write_text("OUTSIDE-SECRET")
        (self.source / "secret-name").symlink_to(outside)
        (self.source / ".backupignore").write_text("**/\n!build/\n!build/keep\n")
        self.assert_git_selection()

    def test_directory_rule_order_matches_git(self):
        self.tree()
        for rules in (
            "build/\n!build/keep\n",
            "build/\n!build/\nbuild/*\n!build/keep\n",
            "**/\n!build/\n!build/keep\n",
            "cache/  \n",
            "cache/\n!cache\n",
            "*\n!build/\nbuild/*\n!build/keep\n",
        ):
            with self.subTest(rules=rules):
                (self.source / ".backupignore").write_text(rules)
                self.assert_git_selection()

    def assert_git_selection(self):
        oracle = Path(tempfile.mkdtemp(prefix="git-oracle-", dir=self.root)) / "tree"
        shutil.copytree(self.source, oracle, symlinks=True)
        rules = (self.source / ".backupignore").read_text()
        (oracle / ".gitignore").write_text(rules)
        subprocess.run(["git", "init", "-q", str(oracle)], check=True)
        with backup.Source(self.source) as source:
            selection = source.scan()
        # Git traversal, not a directory path with a final slash, decides whether to descend
        listed = subprocess.run(
            [
                "git",
                "-c",
                "core.excludesFile=/dev/null",
                "-C",
                str(oracle),
                "ls-files",
                "-o",
                "--exclude-standard",
            ],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.splitlines()
        expected = set(listed)
        actual = {
            entry.name
            for entry in selection.included
            if not stat.S_ISDIR(entry.info.st_mode)
        }
        self.assertEqual(actual, expected)

    def test_invalid_previous_marker_blocks_cleanup(self):
        (self.source / "data").write_text("first")
        code, _, err = self.cli()
        self.assertEqual(code, 0, err)
        old = {p: p.read_bytes() for p in self.remote.rglob("*") if p.is_file()}
        marker = next(self.remote.rglob("*.complete.json"))
        marker.write_text("{}\n")
        (self.source / "data").write_text("second")
        code, out, _ = self.cli()
        self.assertEqual(code, 1)
        self.assertEqual(out, "")
        self.assertEqual(marker.read_text(), "{}\n")
        for path, data in old.items():
            if path != marker:
                self.assertEqual(path.read_bytes(), data)

    def test_destination_and_remote_name_are_validated(self):
        (self.source / "data").write_text("x")
        base = ["--config", str(self.config), "archive", str(self.source), "--to"]
        for destination in ["", "a:b", "../up", "a/../b"]:
            code, out, _ = self.cli(base + [destination, "--dry-run"])
            self.assertEqual(code, 1, destination)
            self.assertEqual(out, "")
        code, out, _ = self.cli(
            [
                "--config",
                str(self.config),
                "--remote",
                "bad name",
                "archive",
                str(self.source),
                "--to",
                "x",
                "--dry-run",
            ]
        )
        self.assertEqual(code, 1)
        self.assertEqual(out, "")

    def test_auth_failure_preserves_old_config_bytes(self):
        client = self.root / "client.json"
        client.write_text(
            json.dumps(
                {
                    "installed": {
                        "client_id": "new-id",
                        "client_secret": "new-secret",
                    }
                }
            )
        )
        config = self.root / "oauth" / "rclone.conf"
        config.parent.mkdir(mode=0o700)
        config.write_text(
            "[drive-backup]\n"
            "type = drive\n"
            'token = {"refresh_token": "old-refresh"}\n'
            "root_folder_id = old-root\n"
            "team_drive = old-team\n"
            "\n[other]\n"
            "type = local\n"
        )
        config.chmod(0o600)
        before = config.read_bytes()

        # The candidate is written, but rclone saves no token into it
        with mock.patch.object(backup.sys.stdin, "isatty", return_value=True), \
             mock.patch.object(backup.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)):
            code, out, err = self.cli(
                ["--config", str(config), "auth", "--client-secret", str(client)]
            )
        self.assertEqual(code, 1)
        self.assertEqual(out, "")
        self.assertEqual(config.read_bytes(), before)
        self.assertNotIn("new-secret", err)
        self.assertEqual(
            sorted(p.name for p in config.parent.iterdir()),
            ["rclone.conf", "rclone.conf.drive-backup.lock"],
        )

    def test_auth_candidate_drops_old_account_ids(self):
        client = self.root / "client.json"
        client.write_text(
            json.dumps(
                {
                    "installed": {
                        "client_id": "new-id",
                        "client_secret": "new-secret",
                    }
                }
            )
        )
        config = self.root / "oauth" / "rclone.conf"
        config.parent.mkdir(mode=0o700)
        config.write_text(
            "[drive-backup]\n"
            "type = drive\n"
            'token = {"refresh_token": "old-refresh"}\n'
            "root_folder_id = old-root\n"
            "team_drive = old-team\n"
            "\n[other]\n"
            "type = local\n"
        )
        config.chmod(0o600)
        seen = {}

        def oauth(args, **kwargs):
            with self.assertRaises(backup.BackupError):
                with backup.config_lock(config):
                    self.fail("the config lock is not held during auth")
            candidate = Path(args[2])
            seen["path"] = candidate
            seen["text"] = candidate.read_text()
            with candidate.open("a") as stream:
                stream.write('token = {"refresh_token": "new-refresh"}\n')
            return subprocess.CompletedProcess(args, 0)

        with mock.patch.object(backup.sys.stdin, "isatty", return_value=True), \
             mock.patch.object(backup.subprocess, "run", side_effect=oauth):
            code, out, err = self.cli(
                ["--config", str(config), "auth", "--client-secret", str(client)]
            )
        self.assertEqual(code, 0, err)
        self.assertNotEqual(seen["path"], config)
        self.assertEqual(seen["path"].parent, config.parent)
        for old in ("old-refresh", "old-root", "old-team"):
            self.assertNotIn(old, seen["text"])
        self.assertIn("new-id", seen["text"])
        self.assertIn("new-secret", seen["text"])
        self.assertIn("[other]", seen["text"])
        live = config.read_text()
        self.assertIn("new-refresh", live)
        for old in ("old-refresh", "old-root", "old-team"):
            self.assertNotIn(old, live)
        self.assertIn("[other]", live)
        self.assertEqual(stat.S_IMODE(config.stat().st_mode), 0o600)

    def test_config_lock_refuses_concurrent_auth_and_archive(self):
        (self.source / "data").write_text("x")
        client = self.root / "client.json"
        client.write_text(
            json.dumps(
                {"installed": {"client_id": "id", "client_secret": "secret"}}
            )
        )
        with backup.config_lock(self.config):
            code, out, _ = self.cli()
            self.assertEqual(code, 1)
            self.assertEqual(out, "")
            code, out, _ = self.cli(
                ["--config", str(self.config), "auth", "--client-secret", str(client)]
            )
            self.assertEqual(code, 1)
            self.assertEqual(out, "")
        self.assertEqual(list(self.remote.iterdir()), [])

    def test_config_lock_is_held_during_archive_remote_calls(self):
        (self.source / "data").write_text("x")
        original = backup.Remote.run

        def run(remote, *args, **kwargs):
            with self.assertRaises(backup.BackupError):
                with backup.config_lock(self.config):
                    self.fail("the config lock is not held during archive")
            return original(remote, *args, **kwargs)

        with mock.patch.object(backup.Remote, "run", run):
            code, _, err = self.cli()
        self.assertEqual(code, 0, err)

    def test_dry_run_takes_no_config_lock(self):
        (self.source / "data").write_text("x")
        with backup.config_lock(self.config):
            code, out, err = self.cli(self.args + ["--dry-run"])
        self.assertEqual(code, 0, err)
        self.assertIn("data", json.loads(out)["included"])

    def test_config_lock_path_is_the_shared_protocol(self):
        with backup.config_lock(self.config):
            lock = self.config.parent / (self.config.name + ".drive-backup.lock")
            self.assertTrue(lock.exists())

    def test_human_messages_use_kaomoji_and_json_stays_plain(self):
        code, out, err = self.cli(self.args + ["--dry-run"])
        self.assertEqual(code, 0, err)
        self.assertTrue(any(ord(c) > 127 for c in err), err)
        self.assertTrue(out.isascii(), out)
        (self.source / ".backupignore").write_text("")
        (self.source / "data").write_text("x")
        code, out, err = self.cli()
        self.assertEqual(code, 0, err)
        self.assertTrue(any(ord(c) > 127 for c in err), err)
        self.assertTrue(out.isascii(), out)
        (self.source / "data").chmod(0)
        code, out, err = self.cli()
        self.assertEqual(code, 1)
        self.assertEqual(out, "")
        self.assertTrue(any(ord(c) > 127 for c in err), err)
        (self.source / "data").chmod(0o600)
        self.assertTrue(backup.parser().format_help().isascii())


if __name__ == "__main__":
    unittest.main()
