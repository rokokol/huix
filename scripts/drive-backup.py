#!/usr/bin/env python3
import argparse
import configparser
import fcntl
import hashlib
import json
import os
import re
import stat
import subprocess
import sys
import tarfile
import tempfile
import uuid
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path, PurePosixPath

from pathspec import GitIgnoreSpec


class BackupError(Exception):
    pass


SUCCESS = "(´｡• ᵕ •｡`)"
WARNING = "(・_・;)"
ERROR = "(｡•́︿•̀｡)"
INFO = "(・ω・)"


def note(mark, message):
    print(f"{mark} {message}", file=sys.stderr)


def fingerprint(info):
    return (
        info.st_dev,
        info.st_ino,
        info.st_mode,
        info.st_size,
        info.st_mtime_ns,
        info.st_ctime_ns,
    )


def unchanged(actual, expected):
    if fingerprint(actual) != fingerprint(expected):
        raise BackupError("Source changed; no new generation is complete")


def readable(info):
    if not info.st_mode & 0o444:
        raise BackupError("Source contains an unreadable entry")


@dataclass(frozen=True)
class Entry:
    name: str
    info: os.stat_result
    link: str = ""


@dataclass
class Selection:
    included: list
    excluded: list
    observed: dict


class Source:
    def __init__(self, path):
        self.path = Path(path).expanduser().resolve(strict=True)
        self.fd = os.open(self.path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        self.root_info = os.fstat(self.fd)
        self.warned_missing_ignore = False

    def __enter__(self):
        return self

    def __exit__(self, *args):
        os.close(self.fd)

    def rules(self):
        try:
            info = os.stat(".backupignore", dir_fd=self.fd, follow_symlinks=False)
        except FileNotFoundError:
            if not self.warned_missing_ignore:
                note(WARNING, "no root .backupignore; all entries are eligible")
                self.warned_missing_ignore = True
            empty = GitIgnoreSpec.from_lines([])
            return (empty, empty), None
        if not stat.S_ISREG(info.st_mode):
            raise BackupError("Root .backupignore must be a regular file")
        readable(info)
        fd = os.open(
            ".backupignore", os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=self.fd
        )
        with os.fdopen(fd, "r", encoding="utf-8") as stream:
            unchanged(os.fstat(stream.fileno()), info)
            lines = stream.read().splitlines()
            unchanged(os.fstat(stream.fileno()), info)
        # Match directories without a final slash so dir/** excludes contents, not dir itself
        directory_lines = [
            line.rstrip()[:-1] if line.rstrip().endswith("/") else line
            for line in lines
        ]
        return (GitIgnoreSpec.from_lines(lines),
                GitIgnoreSpec.from_lines(directory_lines)), info

    def scan(self):
        (file_rules, directory_rules), ignore_info = self.rules()
        included, excluded, observed = [], [], {"": os.fstat(self.fd)}

        def visit(fd, prefix):
            before = os.fstat(fd)
            readable(before)
            for name in sorted(os.listdir(fd)):
                relative = f"{prefix}/{name}" if prefix else name
                info = os.stat(name, dir_fd=fd, follow_symlinks=False)
                observed[relative] = info
                directory = stat.S_ISDIR(info.st_mode)
                match_name = relative + "/" if directory else relative
                rules = directory_rules if directory else file_rules
                if rules.match_file(relative):
                    excluded.append(match_name)
                    continue
                if not (
                    directory
                    or stat.S_ISREG(info.st_mode)
                    or stat.S_ISLNK(info.st_mode)
                ):
                    raise BackupError(f"Special file is not supported: {relative!r}")
                link = (
                    os.readlink(name, dir_fd=fd) if stat.S_ISLNK(info.st_mode) else ""
                )
                unchanged(os.stat(name, dir_fd=fd, follow_symlinks=False), info)
                included.append(Entry(relative, info, link))
                if directory:
                    child = os.open(
                        name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd
                    )
                    try:
                        unchanged(os.fstat(child), info)
                        visit(child, relative)
                    finally:
                        os.close(child)
                elif stat.S_ISREG(info.st_mode):
                    readable(info)
            unchanged(os.fstat(fd), before)

        visit(self.fd, "")
        actual_ignore = observed.get(".backupignore")
        if ignore_info is None:
            if actual_ignore is not None:
                raise BackupError("Root .backupignore appeared during selection")
        else:
            if actual_ignore is None:
                raise BackupError("Root .backupignore disappeared during selection")
            unchanged(actual_ignore, ignore_info)
            unchanged(
                os.stat(".backupignore", dir_fd=self.fd, follow_symlinks=False),
                ignore_info,
            )
        unchanged(os.stat(self.path, follow_symlinks=False), self.root_info)
        return Selection(included, excluded, observed)

    @contextmanager
    def parent(self, name, selection):
        fd = os.dup(self.fd)
        try:
            prefix = ""
            for part in name.split("/")[:-1]:
                prefix = f"{prefix}/{part}" if prefix else part
                child = os.open(
                    part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd
                )
                os.close(fd)
                fd = child
                unchanged(os.fstat(fd), selection.observed[prefix])
            yield fd, name.split("/")[-1]
        finally:
            os.close(fd)

    def pack(self, selection, output):
        # Only selected descriptor-relative entries reach tar; tar never walks source paths
        fd = os.open(
            output, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600
        )
        with os.fdopen(fd, "wb") as destination:
            process = subprocess.Popen(
                ["zstd", "-q", "-T0", "-c"],
                stdin=subprocess.PIPE,
                stdout=destination,
                stderr=subprocess.DEVNULL,
            )
            assert process.stdin is not None
            try:
                with tarfile.open(
                    fileobj=process.stdin, mode="w|", format=tarfile.PAX_FORMAT
                ) as tar:
                    for entry in selection.included:
                        with self.parent(entry.name, selection) as (parent, name):
                            unchanged(
                                os.stat(name, dir_fd=parent, follow_symlinks=False),
                                entry.info,
                            )
                            item = tarfile.TarInfo(entry.name)
                            item.mode = stat.S_IMODE(entry.info.st_mode)
                            item.uid, item.gid = entry.info.st_uid, entry.info.st_gid
                            item.mtime = entry.info.st_mtime
                            if stat.S_ISDIR(entry.info.st_mode):
                                item.type = tarfile.DIRTYPE
                                tar.addfile(item)
                            elif stat.S_ISLNK(entry.info.st_mode):
                                item.type = tarfile.SYMTYPE
                                item.linkname = os.readlink(name, dir_fd=parent)
                                if item.linkname != entry.link:
                                    raise BackupError("Source link changed")
                                tar.addfile(item)
                            else:
                                file_fd = os.open(
                                    name,
                                    os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK,
                                    dir_fd=parent,
                                )
                                with os.fdopen(file_fd, "rb") as stream:
                                    unchanged(os.fstat(stream.fileno()), entry.info)
                                    item.size = entry.info.st_size
                                    tar.addfile(item, stream)
                                    unchanged(os.fstat(stream.fileno()), entry.info)
                            unchanged(
                                os.stat(name, dir_fd=parent, follow_symlinks=False),
                                entry.info,
                            )
                process.stdin.close()
                if process.wait() != 0:
                    raise BackupError("zstd failed")
            except BaseException:
                try:
                    process.stdin.close()
                except OSError:
                    pass
                if process.poll() is None:
                    process.terminate()
                process.wait()
                raise
        self.check(selection)

    def check(self, selection):
        final = self.scan()
        if final.observed.keys() != selection.observed.keys():
            raise BackupError("Source entries changed")
        for name, info in selection.observed.items():
            unchanged(final.observed[name], info)


def sha256(path):
    with open(path, "rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def private_config(path):
    info = path.lstat()
    if (
        not stat.S_ISREG(info.st_mode)
        or info.st_uid != os.getuid()
        or info.st_mode & 0o077
        or not info.st_mode & 0o200
        or info.st_nlink != 1
    ):
        raise BackupError(
            "rclone config must be a private writable file owned by this user"
        )
    parent = path.parent.stat()
    if parent.st_uid != os.getuid() or parent.st_mode & 0o022:
        raise BackupError(
            "rclone config directory must be owned by this user and not shared for write"
        )


class Remote:
    def __init__(self, config, name="drive-backup"):
        if not re.fullmatch(r"[A-Za-z0-9_][A-Za-z0-9_.-]*", name):
            raise BackupError("Invalid remote name")
        self.config = Path(config).expanduser().absolute()
        self.name = name

    def run(self, *args, missing_ok=False):
        result = subprocess.run(
            ["rclone", "--config", str(self.config), *map(str, args)],
            check=False,
            capture_output=True,
            text=True,
            stdin=subprocess.DEVNULL,
            umask=0o077,
        )
        if result.returncode:
            if missing_ok and result.returncode in (3, 4):
                return "[]"
            # rclone diagnostics can contain credentials; expose only the operation and status
            raise BackupError(f"rclone {args[0]} failed (exit {result.returncode})")
        return result.stdout

    def path(self, destination, name=""):
        return (
            f"{self.name}:{destination.rstrip('/')}/{name}"
            if name
            else f"{self.name}:{destination}"
        )

    def verify(self, local, remote_path):
        reply = json.loads(
            self.run(
                "lsjson", remote_path, "--stat", "--hash", "--hash-type", "SHA-256"
            )
        )
        digest = reply.get("Hashes", {}).get("sha256", "")
        if (
            reply.get("IsDir") is not False
            or reply.get("Size") != local.stat().st_size
            or not re.fullmatch(r"[0-9a-fA-F]{64}", digest)
            or digest.lower() != sha256(local)
        ):
            raise BackupError(
                "Remote size or SHA-256 is absent or does not match; previous archive retained"
            )


@contextmanager
def pair_lock(key):
    directory = Path("/tmp") / f"drive-backup-locks-{os.getuid()}"
    try:
        directory.mkdir(mode=0o700)
    except FileExistsError:
        pass
    info = directory.lstat()
    if (
        not stat.S_ISDIR(info.st_mode)
        or info.st_uid != os.getuid()
        or stat.S_IMODE(info.st_mode) != 0o700
    ):
        raise BackupError("Unsafe lock directory")
    directory_fd = os.open(directory, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        fd = os.open(
            key + ".lock",
            os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW | os.O_NONBLOCK,
            0o600,
            dir_fd=directory_fd,
        )
        try:
            info = os.fstat(fd)
            if (
                not stat.S_ISREG(info.st_mode)
                or info.st_uid != os.getuid()
                or info.st_nlink != 1
            ):
                raise BackupError("Unsafe lock file")
            try:
                fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError as error:
                raise BackupError(
                    "Another local archive operation holds this pair lock"
                ) from error
            yield
        finally:
            os.close(fd)
    finally:
        os.close(directory_fd)


@contextmanager
def config_lock(config):
    # One lock per config serializes every rclone call of an archive and of an auth
    path = config.parent / (config.name + ".drive-backup.lock")
    parent = path.parent.stat()
    if parent.st_uid != os.getuid() or parent.st_mode & 0o022:
        raise BackupError(
            "Config lock directory must be owned by this user and not shared for write"
        )
    fd = os.open(path, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW | os.O_NONBLOCK, 0o600)
    try:
        info = os.fstat(fd)
        if (
            not stat.S_ISREG(info.st_mode)
            or info.st_uid != os.getuid()
            or info.st_nlink != 1
        ):
            raise BackupError("Unsafe config lock file")
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise BackupError(
                "Another drive-backup operation holds the config lock"
            ) from error
        yield
    finally:
        os.close(fd)


def valid_marker(marker, generation):
    return (
        isinstance(marker, dict)
        and marker.get("version") == 1
        and marker.get("generation") == generation
        and marker.get("archive") == generation + ".tar.zst"
        and marker.get("checksum") == generation + ".tar.zst.sha256"
        and isinstance(marker.get("sha256"), str)
        and re.fullmatch(r"[0-9a-f]{64}", marker["sha256"]) is not None
        and type(marker.get("size")) is int
        and marker["size"] >= 0
    )


def previous_generations(remote, directory):
    listing = json.loads(
        remote.run("lsjson", remote.path(directory), "--files-only", missing_ok=True)
    )
    previous = []
    for item in listing:
        name = item.get("Name", "")
        match = re.fullmatch(r"([0-9a-f]{32})\.complete\.json", name)
        if not match or item.get("IsDir") is not False:
            continue
        marker = json.loads(remote.run("cat", remote.path(directory, name)))
        if not valid_marker(marker, match[1]):
            raise BackupError(
                "Invalid previous completion marker; no remote changes made"
            )
        previous.append(marker)
    return previous


def write_private(path, data):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as stream:
        stream.write(data)


def archive(args):
    destination = str(PurePosixPath(args.to))
    if not args.to or ":" in args.to or ".." in PurePosixPath(args.to).parts:
        raise BackupError("Destination must be a path inside the selected remote")
    remote = Remote(args.config, args.remote)
    with Source(args.source) as source:
        key = hashlib.sha256(
            json.dumps(
                [str(source.path), remote.name, destination], separators=(",", ":")
            ).encode()
        ).hexdigest()
        directory = destination.rstrip("/") + "/drive-backup-" + key
        if args.dry_run:
            selection = source.scan()
            return {
                "included": [entry.name for entry in selection.included],
                "excluded": selection.excluded,
                "destination": remote.path(directory),
                "key": key,
                "dry_run": True,
            }
        private_config(remote.config)
        with pair_lock(key):
            selection = source.scan()
            # Force staging outside the source even when TMPDIR points into it
            temporary_root = next(
                (
                    p
                    for p in (Path("/tmp"), Path("/var/tmp"))
                    if not p.resolve().is_relative_to(source.path)
                ),
                None,
            )
            if temporary_root is None:
                raise BackupError("No temporary directory exists outside the source")
            with tempfile.TemporaryDirectory(
                prefix="drive-backup-", dir=temporary_root
            ) as temp:
                staging = Path(temp)
                staging.chmod(0o700)
                generation = uuid.uuid4().hex
                payload = staging / (generation + ".tar.zst")
                source.pack(selection, payload)
                checksum = staging / (payload.name + ".sha256")
                digest = sha256(payload)
                write_private(checksum, f"{digest}  {payload.name}\n")
                marker = {
                    "version": 1,
                    "generation": generation,
                    "archive": payload.name,
                    "checksum": checksum.name,
                    "sha256": digest,
                    "size": payload.stat().st_size,
                }
                completion = staging / (generation + ".complete.json")
                write_private(completion, json.dumps(marker, sort_keys=True) + "\n")
                with config_lock(remote.config):
                    previous = previous_generations(remote, directory)
                    for local in (payload, checksum, completion):
                        if local == completion:
                            source.check(selection)
                        target = remote.path(directory, local.name)
                        remote.run("copyto", str(local), target)
                        remote.verify(local, target)
                    # A verified completion marker must exist before any prior generation is removed
                    for old in previous:
                        for name in (
                            old["generation"] + ".complete.json",
                            old["archive"],
                            old["checksum"],
                        ):
                            remote.run("deletefile", remote.path(directory, name))
                    note(
                        SUCCESS,
                        f"generation {generation} is complete at {remote.path(directory)}",
                    )
                    return {
                        "generation": generation,
                        "destination": remote.path(directory),
                        "archive": payload.name,
                        "sha256": digest,
                    }


def auth(args):
    if not args.client_secret:
        raise BackupError("Use --client-secret or set DRIVE_BACKUP_CLIENT_SECRET")
    try:
        client = json.loads(Path(args.client_secret).expanduser().read_text())[
            "installed"
        ]
        credentials = [client["client_id"], client["client_secret"]]
        if not all(
            isinstance(value, str) and value and not any(c in value for c in "\r\n\0")
            for value in credentials
        ):
            raise ValueError
    except (KeyError, ValueError, TypeError) as error:
        raise BackupError(
            "Client file must contain an installed OAuth client ID and secret"
        ) from error
    remote = Remote(args.config, args.remote)
    if not sys.stdin.isatty():
        raise BackupError("Auth requires an interactive terminal")
    remote.config.parent.mkdir(parents=True, mode=0o700, exist_ok=True)
    parent_info = remote.config.parent.stat()
    if parent_info.st_uid != os.getuid() or parent_info.st_mode & 0o077:
        raise BackupError("Auth requires a private config directory (mode 0700)")
    with config_lock(remote.config):
        parser = configparser.RawConfigParser()
        if remote.config.exists() or remote.config.is_symlink():
            private_config(remote.config)
            try:
                parser.read(remote.config)
            except configparser.Error as error:
                raise BackupError("Invalid rclone config syntax") from error
        # Recreate the section: an old token or account-specific ID must not survive
        if parser.has_section(remote.name):
            parser.remove_section(remote.name)
        parser.add_section(remote.name)
        for name, value in {
            "type": "drive",
            "scope": "drive",
            "client_id": credentials[0],
            "client_secret": credentials[1],
        }.items():
            parser.set(remote.name, name, value)
        fd, candidate = tempfile.mkstemp(prefix=".oauth-", dir=remote.config.parent)
        try:
            with os.fdopen(fd, "w") as stream:
                parser.write(stream)
                stream.flush()
                os.fsync(stream.fileno())
            note(INFO, "Choose no for a remote host, or yes for a local browser")
            note(WARNING, "rclone may display sensitive authorization data; do not share it")
            result = subprocess.run(
                ["rclone", "--config", candidate, "config", "reconnect", remote.name + ":"],
                check=False, stdout=sys.stderr, umask=0o077,
            )
            if result.returncode:
                raise BackupError(f"rclone auth failed (exit {result.returncode})")
            private_config(Path(candidate))
            configured = configparser.RawConfigParser()
            try:
                configured.read(candidate)
                token = json.loads(configured.get(remote.name, "token"))
                if not isinstance(token, dict) or not token.get("refresh_token"):
                    raise ValueError
            except (configparser.Error, ValueError) as error:
                raise BackupError(
                    "rclone did not save a refresh token; run auth again"
                ) from error
            os.replace(candidate, remote.config)
        finally:
            if os.path.exists(candidate):
                os.unlink(candidate)
    note(SUCCESS, f"OAuth token saved for {remote.name}")
    return {"authenticated": True, "remote": remote.name}


def parser():
    cli = argparse.ArgumentParser(
        prog="drive-backup",
        allow_abbrev=False,
        description="Create an unencrypted cold archive with rclone",
        epilog="Requires Python pathspec, zstd and rclone on Linux. JSON uses stdout; logs use stderr. "
        "Errors exit 1; usage errors exit 2. Locks apply only on this host and user. "
        "Do not run the same pair on multiple hosts. A backend must supply SHA-256; no fallback applies. "
        "Failed generations can remain incomplete; only validated completed generations permit cleanup.",
    )
    cli.add_argument(
        "--config",
        type=Path,
        default=Path("~/.config/drive-backup/rclone.conf").expanduser(),
        help="private writable rclone config (default: %(default)s)",
    )
    cli.add_argument(
        "--remote",
        default="drive-backup",
        help="rclone remote name (default: %(default)s)",
    )
    commands = cli.add_subparsers(dest="command", required=True)
    create = commands.add_parser(
        "archive",
        allow_abbrev=False,
        help="archive a directory with root .backupignore rules",
        description="Preserve modes, empty directories and symbolic links without a target read. "
        "Only root .backupignore applies, with Git rules. Ignored directories are not traversed. "
        "No .gitignore or .ignore applies automatically. Source changes fail the operation.",
    )
    create.add_argument("source", type=Path, help="source directory")
    create.add_argument(
        "--to", required=True, help="destination path inside the remote"
    )
    create.add_argument(
        "--dry-run",
        action="store_true",
        help="print the plan offline; create no files and contact no remote",
    )
    create.set_defaults(operation=archive)
    login = commands.add_parser(
        "auth",
        allow_abbrev=False,
        help="authorize an installed OAuth client through rclone",
    )
    login.add_argument(
        "--client-secret",
        default=os.environ.get("DRIVE_BACKUP_CLIENT_SECRET", "/run/secrets/drive-backup-client"),
        help="installed OAuth JSON (default: DRIVE_BACKUP_CLIENT_SECRET or /run/secrets/drive-backup-client)",
    )
    login.set_defaults(operation=auth)
    return cli


def main(argv=None):
    args = parser().parse_args(argv)
    try:
        result = args.operation(args)
    except (
        BackupError,
        OSError,
        ValueError,
        tarfile.TarError,
        subprocess.SubprocessError,
    ) as error:
        note(ERROR, str(error))
        return 1
    print(json.dumps(result, sort_keys=True, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
