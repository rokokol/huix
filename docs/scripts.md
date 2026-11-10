---
title: Scripts
kind: scripts
---

# Scripts

<!-- generated: scripts -->

## [`scripts/agent-sync.sh`](https://github.com/rokokol/huix/blob/master/scripts/agent-sync.sh)

```
agent-sync.sh — commit what an agent left in its clones, then rebase them on their upstream

  agent-sync.sh REPO...   commit every change in each REPO, then pull --rebase it
  agent-sync.sh help      this text

The subject of the commit is "[USER] sync DATE", where USER runs this script: the agent wrote
the work, not the host it runs on. A clone with nothing to commit gets no commit. A rebase that
conflicts is wound back, so the clone keeps its own commits. The rebase drops a commit of the
clone when the upstream already holds the same patch
Exit 0 when every clone is committed and rebased, 1 when one is not, 2 on a usage error
```

## [`scripts/alert.sh`](https://github.com/rokokol/huix/blob/master/scripts/alert.sh)

```
alert.sh — keep the open problems of this host, and tell the owner when one opens or closes

  alert.sh raise [-q] KEY SUBJECT < BODY   open a problem, or update the one open under KEY
  alert.sh clear KEY                       close the problem open under KEY
  alert.sh sync SOURCE FILE                make the problems under SOURCE:… the causes in FILE
  alert.sh deliver FILE                    send a message that waits in the outbox
  alert.sh reconcile                       close each unit problem whose unit recovered, and
                                           open or close the reboot problem
  alert.sh digest                          mail every open problem, when there is one
  alert.sh list                            print the open problems, one line each

  -q   open the problem in silence: it waits for the digest, and its close is silent too

A problem that opens or closes is mailed to root, sent to the owner's Telegram and handed to
the agent. A problem raised again while open only updates its body. KEY names one problem and
is a file name: letters, digits and . _ : @ - only. A KEY of the form unit:NAME is closed by
reconcile once systemd reports NAME active, or inactive with the result success after a start
since the problem opened, allowing a minute for the alert to reach the registry. A unit that a
failed dependency left inactive keeps the start of its last success, and that stale start predates
the problem and does not close it. A unit that did fail on its own closes after a reset-failed
wiped the properties that said so, because the problem recorded that failure when it opened. The
reboot problem is open while the kernel, initrd or modules of the current system differ from the
booted one

sync reads FILE, one cause a line: a CAUSE made of the same characters as a KEY, a tab, and
its SUBJECT. Each cause is a problem under SOURCE:CAUSE, opened and sent once; each problem
under SOURCE that FILE no longer lists is closed. An empty FILE closes them all; a FILE that
cannot be read, or a cause that is not a key, changes nothing and fails

list prints KEY, the time it opened, and SUBJECT, separated by tabs. Every change is also a
line in $ALERT_STATE/journal: time, OPEN, UPDATE or RESOLVED, KEY, SUBJECT, by tabs

Environment:
  ALERT_STATE          the state directory (required)
  ALERT_MAIL           the command that sends a mail read on stdin (required)
  ALERT_TELEGRAM_API   the Bot API base URL; empty means no Telegram
  ALERT_TELEGRAM_TOKEN, ALERT_TELEGRAM_CHAT  files with the bot's token and the owner's chat id;
                       while either cannot be read, only the mail goes
  ALERT_TELEGRAM_THREAD  the forum topic to post into; empty posts to the chat's General topic
  ALERT_NOTIFY         the command that hands one line of text to the agent; empty means none
  ALERT_METRICS        a file for the open problems as Prometheus text; empty means none
  ALERT_SPAWN          the command that starts "deliver FILE" apart, given FILE; empty means
                       each message is sent in place. With it, a message waits in
                       $ALERT_STATE/outbox until its delivery ends, and reconcile hands on one
                       that a reboot left there
  ALERT_BOOTED, ALERT_CURRENT  the booted and current system (default /run/booted-system and
                       /run/current-system)
Exit 0 done, 1 when the state cannot be written, 2 on a usage error
```

## [`scripts/backup-heartbeat.sh`](https://github.com/rokokol/huix/blob/master/scripts/backup-heartbeat.sh)

```
backup-heartbeat.sh — fail when a node behind this server went quiet

  backup-heartbeat.sh check [-m FILE] [-p FILE] DATA HTPASSWD MAX_AGE MIN_FREE
  backup-heartbeat.sh push [-p FILE] [-l USER]... HTPASSWD MAX_SILENCE < PAGE

  -m FILE   also write the newest snapshot time of each repository, and the free space,
            to FILE as Prometheus text metrics (a missing repository is time 0)
  -p FILE   write each problem to FILE as a cause, one a line: a key, a tab, a subject.
            The run then passes with problems found, and FILE carries them; an empty FILE
            means none
  -l USER   push: a user of HTPASSWD that backs up from this host and pushes nowhere;
            give it once for each such user

DATA is the rest-server data directory. Every user in the HTPASSWD file is one expected
repository at DATA/<user>/, so a user that never pushed is reported as well. The user named
metrics is the exception: rest-server gives that name the metrics page and nothing else. A repository
is stale when the newest file under DATA/<user>/snapshots/ is older than MAX_AGE, written
as a number with s, m, h or d (36h). MIN_FREE is the space the filesystem of DATA must keep
free, a number of bytes with K, M, G or T in powers of 1024 (10G). A repository one level
deeper, at DATA/<user>/<name>/, is not the expected layout: it is reported as missing, with
a note that names the nested path

push reads a Pushgateway metrics page on stdin. Every user in HTPASSWD is one expected node,
which pushes with its own name as the instance label, except each user given with -l: that
one backs up from the server's own host and pushes nowhere. A node fails when its newest
push_time_seconds, over every job, is older than MAX_SILENCE (1h), or when it never pushed.
A node that pushes on time also fails for each problem it reports of itself: a series
node_problem{key="…",summary="…"} with a value above zero, one a problem

Every problem is reported, one line each, and a summary line comes last
Nothing here reaches the network
Exit 0 when nothing is wrong or -p took the problems, 1 when something is wrong, 2 on a
usage error or an HTPASSWD with no user in it
```

## [`scripts/btrbk-metrics.sh`](https://github.com/rokokol/huix/blob/master/scripts/btrbk-metrics.sh)

```
btrbk-metrics.sh — the snapshots of each folder as Prometheus text metrics

  btrbk-metrics.sh write SNAPSHOTS FILE

SNAPSHOTS is btrbk's snapshot directory. Each entry named <folder>.<YYYYMMDDTHHMM>, the
timestamp in local time, is one snapshot of that folder; any other entry is left out.
FILE gets btrbk_snapshots{folder} and btrbk_newest_snapshot_timestamp_seconds{folder},
written beside FILE and renamed over it
Nothing here reaches the network
Exit 0 when FILE is written, 1 when SNAPSHOTS cannot be read, 2 on a usage error
```

## [`scripts/colorpicker.sh`](https://github.com/rokokol/huix/blob/master/scripts/colorpicker.sh)

```
colorpicker.sh — pick a colour off the screen and copy it as a hex value

  colorpicker.sh          pick a colour, copy it, and notify with its HEX and RGB
  colorpicker.sh help     this text

The colour goes to the clipboard as a hex value. The screen shader is off for the pick,
because it would tint the frozen overlay, and comes back on exit
Exit 0 when a colour was picked, 1 when the pick was cancelled
```

## [`scripts/docs-build.py`](https://github.com/rokokol/huix/blob/master/scripts/docs-build.py)

```
usage: docs-build.py [-h] --facts FACTS [--repo REPO] [--out OUT] [--strict]
                     {inject,check,show,scaffold,site}

Render flake facts into the documentation corpus

positional arguments:
  {inject,check,show,scaffold,site}

options:
  -h, --help            show this help message and exit
  --facts FACTS
  --repo REPO
  --out OUT
  --strict              Fail on a page the corpus lacks
```

## [`scripts/docs-mcp.py`](https://github.com/rokokol/huix/blob/master/scripts/docs-mcp.py)

```
usage: docs-mcp.py [-h] [--repo REPO] [--corpus CORPUS] [--search SEARCH]

The documentation of huix over MCP, offline and read-only

options:
  -h, --help       show this help message and exit
  --repo REPO
  --corpus CORPUS  A corpus directory other than the one of this repository
  --search SEARCH  Search once and print the answer, instead of serving MCP
```

## [`scripts/drive-backup.py`](https://github.com/rokokol/huix/blob/master/scripts/drive-backup.py)

The script prints no `--help`: `ModuleNotFoundError: No module named 'pathspec'`

## [`scripts/forgejo-mirrors.sh`](https://github.com/rokokol/huix/blob/master/scripts/forgejo-mirrors.sh)

```
forgejo-mirrors.sh — keep a Forgejo pull mirror of every GitHub repository of a user

  forgejo-mirrors.sh sync [-x NAME]... GITHUB_API GITHUB_TOKEN_FILE FORGEJO_URL FORGEJO_TOKEN_FILE OWNER STATE [FORK...]

  -x NAME   make no mirror of the repository NAME; an existing one is kept

Every repository that GITHUB_API/user/repos lists as the user's own gets a mirror under OWNER
on FORGEJO_URL, except the forks; a fork named as a FORK gets one too. A mirror is private
when its repository is, and only a private mirror is given the token, so a public one is not
touched when the token changes. Forgejo cannot change the credentials of a mirror, so when the
token differs from the one the last full run saw (its hash in STATE), each private mirror is
made again: the new one is made beside it as <name>-renewing, then takes its place. A run that
stops halfway finishes the swap the next time. A failed clone leaves Forgejo an empty mirror,
so an empty mirror of a repository that GitHub reports as not empty is made again the same
way. A mirror whose repository left GitHub is kept, and a repository of OWNER that is not a
mirror is never touched

GITHUB_PER_PAGE sets the page size of the GitHub list, 100 by default
Exit 0 when every mirror is in place, 1 when GitHub or Forgejo refused a request or a FORK is
not among the user's repositories, 2 on a usage error
```

## [`scripts/grafana-alerts.py`](https://github.com/rokokol/huix/blob/master/scripts/grafana-alerts.py)

```
usage: grafana-alerts.py [-h] --address ADDRESS --port PORT
                         --state-dir STATE_DIR

Pass Grafana webhooks to the alert registry

options:
  -h, --help            show this help message and exit
  --address ADDRESS
  --port PORT
  --state-dir STATE_DIR
```

## [`scripts/hermes-monitor.py`](https://github.com/rokokol/huix/blob/master/scripts/hermes-monitor.py)

```
usage: hermes-monitor.py [-h] --home HOME --state-dir STATE_DIR
                         --metrics METRICS --key-file KEY_FILE
                         --bot-token-file BOT_TOKEN_FILE
                         --chat-id-file CHAT_ID_FILE
                         [--low-balance LOW_BALANCE] [--api API]
                         [--telegram-api TELEGRAM_API]
                         [--telegram-thread-id TELEGRAM_THREAD_ID]

Export Hermes usage and OpenRouter budgets, and report low balances

options:
  -h, --help            show this help message and exit
  --home HOME
  --state-dir STATE_DIR
  --metrics METRICS
  --key-file KEY_FILE
  --bot-token-file BOT_TOKEN_FILE
  --chat-id-file CHAT_ID_FILE
  --low-balance LOW_BALANCE
  --api API
  --telegram-api TELEGRAM_API
  --telegram-thread-id TELEGRAM_THREAD_ID
                        Topic for balance and budget notices
```

## [`scripts/hermes-notify.py`](https://github.com/rokokol/huix/blob/master/scripts/hermes-notify.py)

```
usage: hermes-notify.py [-h] --secret-file SECRET_FILE --url URL
                        text [text ...]

Deliver an alert to the local Hermes webhook with a timestamp-bound HMAC

positional arguments:
  text

options:
  -h, --help            show this help message and exit
  --secret-file SECRET_FILE
  --url URL
```

## [`scripts/hindsight-monitor.py`](https://github.com/rokokol/huix/blob/master/scripts/hindsight-monitor.py)

```
usage: hindsight-monitor.py [-h] --metrics METRICS --key-file KEY_FILE
                            --token-file TOKEN_FILE --state-dir STATE_DIR
                            --bank BANK [--api API]
                            [--api-hindsight API_HINDSIGHT]

Export the OpenRouter spend of Hindsight's key and observed rerank model calls

options:
  -h, --help            show this help message and exit
  --metrics METRICS
  --key-file KEY_FILE
  --token-file TOKEN_FILE
  --state-dir STATE_DIR
  --bank BANK
  --api API
  --api-hindsight API_HINDSIGHT
```

## [`scripts/install-station.sh`](https://github.com/rokokol/huix/blob/master/scripts/install-station.sh)

```
install-station.sh — erase the station's disk and install its system there, then power off

  install-station.sh        install, asking nothing; any key in the countdown stops it
  install-station.sh help   this text

The configuration of the image sets the variables. STATION_DISK is the disk to erase, by its
/dev/disk/by-id path. STATION_DISKO is the disko program that erases, partitions and mounts it
under STATION_ROOT. STATION_SYSTEM is the system to install. STATION_KEY_PATH is where the
installed system reads its age key, and STATION_TAILSCALE_DIR is the state directory of its
tailscaled.

Nothing is touched unless the machine booted in UEFI mode, STATION_DISK exists, a mounted or
mountable ISO 9660 medium holds the directory station-secrets with valid secrets, and a 30 s
countdown on the terminal passes with no key pressed. A refusal or a failed step prints its
reason and leaves a root shell on the terminal; the machine stays on. Everything printed also
goes to /run/station-install.log
Nothing here reaches the network
Exit 0 when the system is installed and the power-off is asked for, 1 when it stops without a
terminal to leave a shell on, 2 on a usage error or a missing variable
```

## [`scripts/lid-mode.sh`](https://github.com/rokokol/huix/blob/master/scripts/lid-mode.sh)

```
lid-mode.sh — the "lid blanks the screen instead of suspending" mode (bind SUPER+SHIFT+A)

Commands:
  toggle    turn the mode on/off
  on|off    turn on/off explicitly
  close     lid-close handler (bindl switch:on:Lid Switch)
  open      lid-open handler (bindl switch:off:Lid Switch)
  status    print the current state (on|off) — for scripts
  help      this help

While the mode is on, logind doesn't touch the lid, and Hyprland via the switch binds
blanks only the internal panel through dpms — an external monitor, if attached, keeps
working

The mode lives only within the session, and after a reboot/relogin the laptop suspends
on the lid again — deliberately, so you don't leave it enabled in a bag
```

## [`scripts/make-station-iso.sh`](https://github.com/rokokol/huix/blob/master/scripts/make-station-iso.sh)

```
make-station-iso.sh — copy the station's installer image with its secrets added inside

  make-station-iso.sh write [-s DIR] ISO OUTPUT   write OUTPUT: ISO with the secrets of DIR inside
  make-station-iso.sh help                        this text

  -s DIR   the directory with age-key.txt (the station's age key) and tailscale-state.tar (a
           tar whose one top-level directory ts-state/ holds a tailscaled state directory);
           default: $XDG_STATE_HOME/huix/station-bootstrap, with ~/.local/state in place of an
           unset XDG_STATE_HOME

ISO is the image `nix build .#station-installer` makes, in result/iso/. The copy keeps its boot
records and gains /station-secrets, readable by root alone. OUTPUT must not exist yet and must
not be inside a git work tree or the Nix store (NIX_STORE_DIR, default /nix/store); it is
created readable by its owner alone. The secrets are read from DIR and written into OUTPUT,
and nowhere else. OUTPUT is a secret itself: delete it once the station is installed
Nothing here reaches the network
Exit 0 when OUTPUT is written, 1 when a secret, the image or the write is wrong, 2 on a usage
error or a refused OUTPUT
```

## [`scripts/memory-status.sh`](https://github.com/rokokol/huix/blob/master/scripts/memory-status.sh)

```
memory-status.sh — used RAM, and used swap when there is any, as one waybar JSON line

  memory-status.sh status   print {"text":…,"tooltip":…}
  memory-status.sh help     this text

The text is "<ram>Gb 🧠" with no swap device, "<ram>/<swap>Gb 🧠" with one, and
"<ram>/<swap>+<swap>Gb 🧠" with more, the swap in use on each device from the highest priority
down; the kernel fills them in that order. The tooltip names each device
Environment: HUIX_MEMINFO and HUIX_SWAPS are the files read (default /proc/meminfo and
/proc/swaps)
Nothing here reaches the network
Exit 0 done, 1 when the memory file cannot be read, 2 on a usage error
```

## [`scripts/notify-center.sh`](https://github.com/rokokol/huix/blob/master/scripts/notify-center.sh)

```
notify-center.sh — notification center on top of mako (=^･ω･^=)

Commands:
  status              JSON for waybar (custom/notifications)
  dnd toggle|on|off   toggle "do not disturb"
  dnd status          prints on|off
  clear               clear the whole history
  menu                "id<US>icon<US>label" lines for rofi (newest on top)
  text <id>           notification text (for copying)
  help                this help

The feed = visible popups + mako history, newest on top, nothing is filtered out.
The only operation on an entry is copying the text; notification actions (buttons)
are available natively and only on visible popups: LMB — default action, RMB —
makoctl menu. History is cleared only as a whole

DND lives in the daemon's runtime: it survives a Hyprland reload and nixos-rebuild, but
resets when the session restarts
```

## [`scripts/ocr.sh`](https://github.com/rokokol/huix/blob/master/scripts/ocr.sh)

```
scripts/ocr.sh: line 9: slurp: command not found
```

## [`scripts/or-transcribe.py`](https://github.com/rokokol/huix/blob/master/scripts/or-transcribe.py)

```
usage: or-transcribe.py [-h] --model MODEL [--language LANGUAGE]
                        [--prompt PROMPT] [--no-zdr] [--chunk-sec CHUNK_SEC]
                        [--silence-db SILENCE_DB] [--silence-len SILENCE_LEN]
                        [--json] [--cost]
                        [audio ...]

Transcribe audio through the OpenRouter transcriptions endpoint

positional arguments:
  audio                 audio file(s); anything ffmpeg opens (default: None)

options:
  -h, --help            show this help message and exit
  --model MODEL         OpenRouter model id
  --language LANGUAGE   ISO-639-1 hint; 'auto' to let the model decide
                        (default: ru)
  --prompt PROMPT       vocabulary/spelling hint passed to the model (default:
                        )
  --no-zdr              allow providers that keep the audio (ZDR is on by
                        default) (default: False)
  --chunk-sec CHUNK_SEC
                        longest piece sent in one request (default: 300.0)
  --silence-db SILENCE_DB
                        silence threshold (default: -30.0)
  --silence-len SILENCE_LEN
                        minimum silence length (default: 0.3)
  --json                emit JSON instead of plain text (default: False)
  --cost                print cost and duration to stderr (default: False)

Prints the transcript on stdout; progress and errors go to stderr. With no
file it reads the path list from stdin, one per line.
```

## [`scripts/paste-as-file.sh`](https://github.com/rokokol/huix/blob/master/scripts/paste-as-file.sh)

```
paste-as-file.sh — write the clipboard into a folder as a file and print its path

  paste-as-file.sh [DIR]          paste into DIR, or into $PWD when DIR is absent
  paste-as-file.sh help           this text

An image becomes img.png with the extension of its MIME type, text and a copied path
become text.txt, and a name already taken gains a number: img-1.png. DIR may be a file, in
which case its folder is used. A clipboard of no supported type writes nothing and exits 0
```

## [`scripts/pin-screen.sh`](https://github.com/rokokol/huix/blob/master/scripts/pin-screen.sh)

```
scripts/pin-screen.sh: line 8: slurp: command not found
```

## [`scripts/random-wallpaper.sh`](https://github.com/rokokol/huix/blob/master/scripts/random-wallpaper.sh)

```
random-wallpaper.sh — draw a collage of random gallery pictures and set it as the wallpaper

  random-wallpaper.sh          build a collage and hand it to awww
  random-wallpaper.sh help     this text

Six pictures at most come from the gallery of the vault, each rotated, jittered and given a
shadow, and the result fades in with a random transition. Nothing happens while the lock
screen is up, because the collage is not visible there
Exit 0 when the wallpaper is set, 1 when the gallery holds no picture
```

## [`scripts/restic-cloud.py`](https://github.com/rokokol/huix/blob/master/scripts/restic-cloud.py)

```
usage: restic-cloud.py [-h] {mirror,check} ...

Copy encrypted restic repositories from a read-only Btrfs snapshot

positional arguments:
  {mirror,check}
    mirror        Update an owned cloud mirror
    check         Fail when the last successful mirror is too old

options:
  -h, --help      show this help message and exit
```

## [`scripts/rofi-clipboard.sh`](https://github.com/rokokol/huix/blob/master/scripts/rofi-clipboard.sh)

```
rofi-clipboard.sh — pick an entry of the clipboard history in rofi and copy it back

  rofi-clipboard.sh          open the history in rofi and copy the entry chosen
  rofi-clipboard.sh help     this text

The history comes from cliphist, and an image entry shows its preview. Return copies the
entry, Control+Return copies the typed text as it is, Delete removes the entry, and Escape
leaves the clipboard as it was
```

## [`scripts/rofi-notify.sh`](https://github.com/rokokol/huix/blob/master/scripts/rofi-notify.sh)

```
rofi-notify.sh — the notification centre as a rofi mode

  rofi-notify.sh          open the notification centre in rofi
  rofi-notify.sh help     this text

Called from rofi as a script mode, the mode lists the history, offers a do-not-disturb
toggle and a clear, and copies the text of the notification chosen. Run outside rofi it
starts rofi with this mode instead. The history itself belongs to notify-center.sh
```

## [`scripts/rofi-open-with.sh`](https://github.com/rokokol/huix/blob/master/scripts/rofi-open-with.sh)

```
rofi-open-with.sh — pick the app that opens a file, in rofi

  rofi-open-with.sh open FILE...    show the apps for the type of the first FILE
  rofi-open-with.sh list MODE       the rofi side of a mode: suggested or all

In rofi, Ctrl+Tab switches between the apps for the type and all apps
The chosen app gets every FILE
Exit 0 done, 1 when a FILE does not exist, 2 on a usage error
```

## [`scripts/rofi-power.sh`](https://github.com/rokokol/huix/blob/master/scripts/rofi-power.sh)

```
rofi-power.sh — the power menu as a rofi mode

  rofi-power.sh          open the power menu in rofi
  rofi-power.sh help     this text

The menu offers lock, screen off, suspend, reboot, log out and power off, and every one of
them goes through logind, systemctl or Hyprland rather than doing the work here. Run outside
rofi it starts rofi with this mode instead
```

## [`scripts/rotate-screen.sh`](https://github.com/rokokol/huix/blob/master/scripts/rotate-screen.sh)

```
rotate-screen.sh — rotate a monitor together with its touch and pen input (Hyprland transform)

  rotate-screen.sh [-m MONITOR] set N     transform N: 0 upright, 1 90°, 2 180°, 3 270°
  rotate-screen.sh [-m MONITOR] next      one step through 0, 1, 2, 3 and around
  rotate-screen.sh [-m MONITOR] prev      one step back
  rotate-screen.sh [-m MONITOR] status    print the current transform number
  rotate-screen.sh [-m MONITOR] auto      follow the accelerometer until stopped

  -m MONITOR   a name from hyprctl monitors (default: the focused monitor; for auto, the
               built-in panel)

auto reads monitor-sensor from iio-sensor-proxy and maps normal, left-up, bottom-up and
right-up to 0, 1, 2 and 3; it runs until killed, which is what the huix-auto-rotate user
unit does. The touch and pen transforms are global in Hyprland, so rotating one monitor
of several turns them as well
Nothing here reaches the network
Exit 0 done, 1 when the monitor is not there or Hyprland refuses, 2 on a usage error
```

## [`scripts/shot-copy.sh`](https://github.com/rokokol/huix/blob/master/scripts/shot-copy.sh)

```
shot-copy.sh — screenshot to the clipboard with a preview of its size

  shot-copy.sh             select a region and copy it
  shot-copy.sh full        copy the whole screen
  shot-copy.sh help        this text

The picture goes to the clipboard at once and a notification shows its size; the file lives
five seconds and is removed. The size is the one of the PNG, which on a scaled output is
larger than the selection. Cancelling the selection copies nothing and exits 0
```

## [`scripts/sync.sh`](https://github.com/rokokol/huix/blob/master/scripts/sync.sh)

```
sync.sh — huix repository sync (alias: syssync)

Usage:
  sync.sh                pull --rebase, stage everything, commit "[host] sync <date>", push
  sync.sh "message"      the same, with your own commit subject
  sync.sh --pull-only    fetch + merge --ff-only and nothing else (what sync.service runs)
  sync.sh --no-projects  skip the sweep below, huix only
  sync.sh --no-take      leave the agents' clones alone, see below
  sync.sh --help         this help

Exit 0 when huix is in sync, 1 when a git step failed, timed out or left a conflict. The
sweep never decides the status: a repository it could not move is reported and passed over

The commit mode also takes an agent's work into huix. That holds for each line of the
SYNC_REMOTES file below with huix's origin and a fourth field UNIT. First UNIT starts over ssh
on the host before the colon of URL: it commits whatever the agent left as "[USER] sync DATE"
and rebases the agent's clone on GitHub. After huix's own commit, each commit of the clone that
huix lacks is cherry-picked, and the owner hears what was taken under the remote's name. When
something was taken, huix pulls once more, which drops a copy of an upstream commit the clone
got after huix's first pull. After the push UNIT starts again, and the clone drops its copies
of what is now upstream. An agent out of reach is reported and passed over. A conflict is
wound back, leaves the agent's commits in its clone and makes the exit status 1. When taking
leaves HEAD without a commit it held before, nothing is pushed, the exit status is 1, and the
notice names the commit to fast-forward back to

Both modes end by catching every git repository under the roots PROJECTS_DIR names, up to
its upstream; PROJECTS_DIR is a colon-separated list of directories. The search is
recursive, but stops at the first directory containing .git. Without local commits it
fast-forwards; with them it rebases them on top, autostashing a dirty tree, and winds the
whole thing back if that would conflict. It never commits and never pushes, a repository with
no upstream is left alone, and one holding a .git/nosync file is skipped before it is even
fetched. A name marked * in the summary was rebased rather than fast-forwarded

Before that, each line "NAME ORIGIN URL [UNIT]" of the file SYNC_REMOTES gives every checkout
whose origin is ORIGIN, huix and the sweep's own, a remote NAME at URL. The remote is fetched,
and its commits that no branch holds are reported; it is removed once its line is gone. Only
the commit mode above merges, into huix and from a line with a UNIT. A remote not made from
that file is never touched, and --no-projects limits this to huix

The huix history is written by hand. The session/rebuild unit only fast-forwards, so it never
rebases local commits and never touches a dirty tree — when it cannot fast-forward it just
says so. Staging is -A, so a new file goes up without a separate git add
```

## [`scripts/tablet-mode.sh`](https://github.com/rokokol/huix/blob/master/scripts/tablet-mode.sh)

```
tablet-mode.sh — the folded-laptop mode: auto-rotation, titlebars, no cursor, on-screen keyboard

  tablet-mode.sh on                                 enter the mode
  tablet-mode.sh off                                leave it
  tablet-mode.sh toggle                             one or the other
  tablet-mode.sh lock on|off|toggle                 hold or release the screen's orientation
  tablet-mode.sh lock status                        print on or off
  tablet-mode.sh sync                               follow the tablet-mode switch
  tablet-mode.sh status                             print on or off
  tablet-mode.sh virt-keyboard toggle|show|hide     the on-screen keyboard, in either mode
  tablet-mode.sh virt-keyboard status               the bar button as waybar JSON: the
                                                    keyboard glyph in the mode, nothing outside it

sync is for the start of the session and every Hyprland reload: switch binds fire only on
a change, and a reload resets the transform and the titlebars to the config. Every hold
and release of the rotation lock pops one low-urgency note about what the screen does now
Environment: HUIX_TABLET_SWITCH names the switch device sync reads (as hyprctl devices
prints it); HUIX_INPUT_DEVICES is where the kernel lists input devices (default
/proc/bus/input/devices); HUIX_TABLET_SIGNAL is the N of the SIGRTMIN+N waybar refreshes
the button on, unset when no bar shows one; HUIX_ROTATION_LOCK is where the rotation lock
file lives (default $XDG_RUNTIME_DIR/huix-rotation-lock)
Nothing here reaches the network
Exit 0 done, 1 when a unit, the switch or the keyboard cannot be reached, 2 on a usage error
```

## [`scripts/toggle-theme.sh`](https://github.com/rokokol/huix/blob/master/scripts/toggle-theme.sh)

The script prints no `--help`: `GTK_THEME_KEY COLOR_SCHEME_KEY LIGHT_THEME DARK_THEME LIGHT_SCHEME DARK_SCHEME GTK4_LIGHT_CSS GTK4_DARK_CSS`

## [`scripts/touchscreen.sh`](https://github.com/rokokol/huix/blob/master/scripts/touchscreen.sh)

```
touchscreen.sh — the built-in touchscreen off, and back on (bind SUPER+SHIFT+T)

Commands:
  toggle    turn the touchscreen off, or back on
  on|off    turn it on or off explicitly
  apply     re-apply the remembered state (the compositor's start and config reload)
  status    print the current state (on|off) — for scripts
  help      this help

The choice outlives a config reload and a new session: Hyprland re-enables every input
device on a reload, so it is kept in $XDG_STATE_HOME/huix/touchscreen and put back by
`apply`. Off takes the touch gestures with it — the compositor sees no touch at all
```

## [`scripts/wake-pc.sh`](https://github.com/rokokol/huix/blob/master/scripts/wake-pc.sh)

```
wake-pc.sh — wake the PC with a Wake-on-LAN magic packet

  wake-pc.sh        wake the PC and wait until it answers on the tailnet
  wake-pc.sh send   only send the packet
  wake-pc.sh help   this text

The host sets the variables. WAKE_PC_MAC_FILE names a file whose first line is the PC's
MAC address. WAKE_PC_BROADCAST is the broadcast address of the LAN, such as 192.168.0.255:
the packet goes there and leaves on the wired link, past any VPN route. WAKE_PC_HOST is
the PC's name on the tailnet, and WAKE_PC_WAIT the seconds to wait for it, 300 by default
Exit 0 when the PC is on, or the packet is sent for send; 1 when the MAC file cannot be read
or holds no MAC address; 2 on a usage error or a missing variable; 3 when the PC gave no
answer in the wait: it may have no power, or its boot stopped before the network came up
```

## [`scripts/zoom.sh`](https://github.com/rokokol/huix/blob/master/scripts/zoom.sh)

```
zoom.sh — live magnifier: screen zoom around the cursor (Hyprland cursor:zoom_factor)

Usage:
  zoom.sh in|out [step]   closer/farther (multiplier, default 1.3)
  zoom.sh toggle          2.5x or back to 1x (default)
  zoom.sh reset           1x
  zoom.sh --help          this help
```

<!-- /generated -->
