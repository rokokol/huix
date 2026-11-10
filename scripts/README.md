<div align="center">

<img src="../assets/shef-os-320-kg.jpg" alt="the chef cooks the utilities" width="300"/>

<em>320kg scripts 💀</em>

</div>

# Scripts

[![huix](https://img.shields.io/badge/huix-up-222222?style=for-the-badge&logo=nixos&logoColor=white)](../README.md)

Small scripts take the routine off your hands: they help to drive the desktop and the files, and they watch the home server. Applications, key bindings and system units start them

To send the changes of huix, run `syssync`, with a commit message of your own if you like. The automatic sync at login never commits and never pushes

The sync also collects the work of Mya: huix and the projects she keeps on the station get a remote called `mya`, and a notification arrives about her new commits. `syssync` goes further: it first commits everything Mya left in her clone of huix under her name `[mya]`, then brings that into huix and pushes it with your changes. A separate notification says what came from her. When her work is not wanted, `syssync --no-take` leaves it out

One mode is useful when only this repository needs a sync:

```sh
syssync --no-projects
```

Each script carries its own help: `--help` names the commands and their arguments

## Archives on Google Drive

`drive-backup` keeps an unencrypted cold archive of a directory, a SHA-256 file and a completion mark. The command compares the size and the SHA-256 with what Drive holds, and removes the previous archive only after it has checked the new one. Nothing has to be downloaded back. `drive-backup --help` is the reference, and without an install the command runs through `nix run .#drive-backup -- --help`

A `.backupignore` file at the root of the source directory holds the exclusions in the format of a Git ignore, negations and root anchoring included. The rules apply before the packing, and nested `.backupignore`, `.gitignore` and `.ignore` files are not applied by themselves. A `--dry-run` preview shows the contents of the archive without packing and without reaching Drive, and leaves out the previous archive, which would take a call to Drive. Without a `.backupignore` the command warns that nothing is excluded, and never looks for secrets in the content

The archive keeps the permissions, the empty directories and the symbolic links, and never reads what a link points at. A change of the source data during the packing stops the upload. A database needs a consistent dump first, not an archive of a live directory

Another run for the same source directory and destination keeps one finished archive. The command never removes other sets or files it did not write. Two runs on one machine block each other, and one shared cloud directory should not be updated from two machines at once

The authorisation through an OAuth client of your own is done explicitly, as the user who will run the command: `drive-backup auth`. The client lives in sops, and the renewable token lives in a private mutable config of rclone, outside Git and outside the Nix store. To switch accounts, make separate connections with `--remote NAME auth` and pick one with the same `--remote` before `archive`. A failed reauthorisation keeps the previous token. An OAuth application left in the "Testing" mode asks for a reauthorisation every week

The token of the station is its own. Log into the station over SSH and run `sudo drive-backup --config /var/lib/restic-cloud/rclone.conf auth`, choosing the account that should hold the automatic copy. Tell rclone the station has no browser: it prints a command for a machine that has one and asks for the answer back in the SSH terminal. Both the command and the answer carry secrets, so do not publish them. Then `sudo systemctl start restic-cloud.service` and read the journal: the new account gets a folder of its own, and the previous one stays as it was. The age of the last copy is checked for the chosen account and destination

A delete on Drive behaves as rclone always does: the outdated objects go to the Google Drive bin, and they may hold quota until the bin is emptied

To run the tests of the scripts by hand:

```sh
nix develop -c bash scripts/tests/run.sh
```
