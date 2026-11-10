<div align="center">

<img src="../../assets/sayori-v-korobke.jpg" alt="every service in its own little box" width="300"/>

<em>every service is packed neatly into its own box</em>

</div>

# Services

[![huix](https://img.shields.io/badge/huix-up-222222?style=for-the-badge&logo=nixos&logoColor=white)](../../README.md)
[![nixos](https://img.shields.io/badge/nixos-system_layer-5277C3?style=for-the-badge&logo=nixos&logoColor=white)](../README.md)
[![fonts](https://img.shields.io/badge/fonts-fonts-EA4AAA?style=for-the-badge&logo=googlefonts&logoColor=white)](../fonts/README.md)
[![DDLC](https://img.shields.io/badge/DDLC-login_theme-FF80C0?style=for-the-badge&logo=qt&logoColor=white)](https://github.com/rokokol/ddlc-sddm-theme)

The services that tie the hosts together, watch how they are doing and provide the usual tools run here

The work hosts carry the services of everyday work, and the home server takes the network tasks and the backups

## The network

Some services work on their own machine alone, and others are reachable from the devices of the private network. A few web interfaces open from the home network too

## Services

- **AI and search**: run a local language model, or look something up on the web
- **Connection**: the private network joins the devices, and a VPN client helps to switch network profiles
- **The health of the machines**: services watch the disks and the metrics. A breakage and its repair are reported once, by mail and in Telegram, and every morning a list of what is still open arrives
- **Monitoring** (station): the graphs answer at a glance whether the hosts and the nodes are well, whether the backups are fresh, whether the disks are healthy and whether the sync is going. Grafana watches the temperature of the station, the fill of the disks and the moment the space runs out by the trend of the week, and reports the finding with the other alerts
- **Backups** (station): keeps the copies of the work machines and helps not to lose them to an accidental delete. A [cloud copy](tools/drive-backup.nix) moves every encrypted restic repository to Google Drive without ever holding their passwords. It takes a read-only Btrfs snapshot without the restic lock files, checks SHA-256 before it removes the outdated objects, and reports a failure or a missing fresh successful run. The history inside the repositories follows the policy of restic itself; the cloud holds one copy of the repositories rather than one restic snapshot
- **Files**: Forgejo keeps the own Git projects and their CI, and Syncthing syncs the notes and the shared user resources of pi; the local state of pi is kept separately for each host
- **The archive of files** (station): a synced file that was deleted or overwritten gives its previous version back
- **Calendar** (station): the schedule and the task list of Mya, shared by the owner and Mya. Super Productivity and the agents of each host work with them directly, and a deleted event can be brought back from a snapshot
- **Agent** (station): Mya, Hermes Agent in Telegram, edits notes, runs scheduled tasks, prints, and controls the power of the PC and the laptop. All about her is in [her README](ai/hermes/README.md)
- **The memory of the agents** (station): [Hindsight](ai/hindsight/README.md) keeps the shared facts of pi and Hermes, with its own authorisation and its own backups of the database
- **Flatpak**: the applications that work badly out of nixpkgs are installed from a list in the configuration of the host. On the PC the graphics driver for them updates together with the system driver of NVIDIA
- **Sensors** (laptop): turn the screen when the laptop folds into a tablet
