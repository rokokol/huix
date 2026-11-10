---
title: nixos/services/tools
kind: module
dir: nixos/services/tools
---

# nixos/services/tools

<!-- generated: module nixos/services/tools -->

## [`nixos/services/tools/dav-mcp.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/tools/dav-mcp.nix)

The Radicale login of one local user, for dav-mcp, the calendar MCP server that the user's
agents start. The server is registered on the Home Manager side, in
home-manager/programs/agents/remote/dav-mcp.nix reads the password file and the URL from here

**Options:** `rokokol.dav-mcp.enable`, `rokokol.dav-mcp.passwordFile`, `rokokol.dav-mcp.url`, `rokokol.dav-mcp.user`

More: [rokokol.dav-mcp options](../options/dav-mcp.md)

## [`nixos/services/tools/drive-backup.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/tools/drive-backup.nix)

**Options:** `rokokol.drive-backup.cloud.configFile`, `rokokol.drive-backup.cloud.destination`, `rokokol.drive-backup.cloud.enable`, `rokokol.drive-backup.cloud.maxAge`, `rokokol.drive-backup.cloud.onCalendar`, `rokokol.drive-backup.enable`

More: [rokokol.drive-backup options](../options/drive-backup.md)

**Units:** `btrbk-restic`, `restic-cloud`, `restic-cloud-heartbeat`

## [`nixos/services/tools/forgejo-mirrors.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/tools/forgejo-mirrors.nix)

Forgejo pull mirrors of the GitHub repositories that the token in the secret
github-mirror-token sees as its user's own. A daily run makes the mirrors that are missing
and keeps them when the token changes; Forgejo itself fetches each mirror on its own interval.
The run talks to Forgejo with an API token of the owner, which the forgejo CLI makes on the
first run; deleting its file makes a new one. Deleting or renaming a repository of a user
takes the user scope as well as the repository one

**Options:** `rokokol.forgejo-mirrors.enable`, `rokokol.forgejo-mirrors.exclude`, `rokokol.forgejo-mirrors.forks`, `rokokol.forgejo-mirrors.githubApi`

More: [rokokol.forgejo-mirrors options](../options/forgejo-mirrors.md)

**Units:** `forgejo-mirrors`

## [`nixos/services/tools/forgejo.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/tools/forgejo.nix)

A Forgejo forge for one owner, reached over HTTP through its tailnet-web site, which the LAN
reaches too. Forgejo itself binds to loopback: its module listens on every address by default.
There is no SSH server and no sign-up. The owner's admin account is made once, with a random
first password that Forgejo asks to change on the first login

**Options:** `rokokol.forgejo.backup.dumpDir`, `rokokol.forgejo.backup.mountPoint`, `rokokol.forgejo.cli`, `rokokol.forgejo.enable`, `rokokol.forgejo.initialPasswordFile`, `rokokol.forgejo.owner`, `rokokol.forgejo.runners`

More: [rokokol.forgejo options](../options/forgejo.md)

**Units:** `forgejo`, `forgejo-dump`, `forgejo-dump-dir`, `forgejo-owner`, `forgejo-runners`, `restic-backups-station`

## [`nixos/services/tools/mail-agent.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/tools/mail-agent.nix)

The seam for the mail skill's service. The module owns the unit, the isolation and
every default; this file supplies the two things it ships none of — where the mailboxes
come from, and who may talk to the socket. Read the module's own options before adding
a line here. The mailboxes are one private file, passwords and own addresses included,
because this repository is public and the addresses are not

**Options:** `rokokol.mail-agent.enable`, `rokokol.mail-agent.socketUser`

More: [rokokol.mail-agent options](../options/mail-agent.md)

## [`nixos/services/tools/paper-search.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/tools/paper-search.nix)

The private settings of paper-search-mcp, the paper search server behind the papers skill.
The server reads them from an env file, so sops renders one and the user layer's seam
(home-manager/programs/agents/research/papers.nix) points the binaries at it. It holds the
Unpaywall address alone, for the open-access step of the download fallback. The sources take
no key: an invalid Semantic Scholar key is refused where no key is answered

**Options:** `rokokol.paper-search.enable`

More: [rokokol.paper-search options](../options/paper-search.md)

## [`nixos/services/tools/radicale.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/tools/radicale.nix)

A CalDAV server for the owner's calendars, reached through its tailnet-web site. Radicale binds
to loopback, and every request needs a login from the htpasswd file. The calendars are plain
files on the backup filesystem, with snapshots every 15 minutes, so an event that a client
deleted can be restored. The calendars themselves are data: a client makes them, and nothing
here names one. Each login in `sharedWith` has the owner's home as its own, through a symlink,
because a CalDAV client lists only the calendars of its own home

**Options:** `rokokol.radicale.dataDir`, `rokokol.radicale.enable`, `rokokol.radicale.localUrl`, `rokokol.radicale.mountPoint`, `rokokol.radicale.owner`, `rokokol.radicale.sharedWith`, `rokokol.radicale.subvolumes`, `rokokol.radicale.url`

More: [rokokol.radicale options](../options/radicale.md)

**Units:** `radicale`

## [`nixos/services/tools/searxng.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/tools/searxng.nix)

**Options:** `rokokol.searxng.enable`, `rokokol.searxng.port`, `rokokol.searxng.publicPort`

More: [rokokol.searxng options](../options/searxng.md)

## [`nixos/services/tools/syncthing.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/tools/syncthing.nix)

Syncthing between the hosts of this flake and the phone. Each host names its own device ID, and
every other host takes it from there; a host with no ID yet is left out. A workstation shares
each folder both ways. An archive host only receives it, unless a user there edits it, and
keeps what a peer deletes or overwrites in snapshots, for the folder's `preserve`

**Options:** `rokokol.syncthing.archive.dir`, `rokokol.syncthing.archive.editor`, `rokokol.syncthing.archive.enable`, `rokokol.syncthing.archive.folders`, `rokokol.syncthing.archive.mountPoint`, `rokokol.syncthing.archive.snapshotDir`, `rokokol.syncthing.archive.subvolumes`, `rokokol.syncthing.deviceId`, `rokokol.syncthing.enable`, `rokokol.syncthing.keyFromSops`

More: [rokokol.syncthing options](../options/syncthing.md)

**Units:** `btrbk-syncthing`, `syncthing`, `syncthing-init`

## [`nixos/services/tools/telegram-agent.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/tools/telegram-agent.nix)

The seam for the telegram skill's service. The module owns the unit, the isolation and
every default; this file supplies the two things it ships none of — where the api pair
comes from, and who may talk to the socket. Read the module's own options before adding
a line here: the permissions directory, the outbox and the sweep are already its own.
One account, one session per host that runs this, so it is gated rather than shared

**Options:** `rokokol.telegram-agent.enable`, `rokokol.telegram-agent.socketUser`

More: [rokokol.telegram-agent options](../options/telegram-agent.md)

<!-- /generated -->
