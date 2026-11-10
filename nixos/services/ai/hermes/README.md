<div align="center">

<img src="../../../../assets/mya-logo.png" alt="Mya" width="200"/>

# Mya

<em>a catgirl maid who lives on the station and answers in Telegram~</em>

</div>

The agent is [Hermes Agent](https://github.com/NousResearch/hermes-agent), running on the station without a screen. The owner talks to her through a Telegram bot, and she works on his notes, his machines and his files

## What she does

- **Talk**: she answers in Telegram, and sends tables and formulas as Rich Messages. The character, the owner's dossier and the memory are hers to keep and to extend
- **Skills**: she writes new skills for herself and reworks them from time to time. The skills of the station and the shared skills of huix she only reads
- **Scheduled tasks**: at the owner's request she sets a task with a schedule, such as a morning letter about what broke, what arrived in the diary, the weather, GitHub and the news
- **Alerts**: the alerts of the station reach the chat and land in her context, so a review starts with her answer and needs no separate session for every alert
- **Notes**: she edits the Obsidian vault. The edits travel to the devices through Syncthing, and the previous versions stay in the archive of the station
- **GitHub**: she reads the repositories of the owner, works through the incoming items, accepts invitations and starts deployments. She holds no tokens of her own: an intermediary on the station keeps them and decides which one a request goes with
- **huix**: she keeps her own clone of the repository
- **Printing**: she prints a file on the printer at the PC, and wakes the PC when it sleeps
- **Calendar**: she sees the schedule of the owner and changes it on request, and keeps the task list. A task with the `mya` category she takes herself and reports the outcome
- **Power**: she wakes the PC, suspends it, locks it, blanks the screen, powers it off and reboots it, on request or by herself. A suspend, a power off and a reboot wait until the owner steps away from the machine. The laptop does not wake over the network
- **The health of the machines**: she learns of the open problems of the station and of the nodes, and can work through them

## Spend and telemetry

The main model is DeepSeek through the OpenCode Go subscription, and when it is unreachable Hermes moves to DeepSeek through OpenRouter. The auxiliary calls — compression, titles, the work with memory — go through the same subscription on GLM 5.3 Flash, with OpenRouter as their reserve. The allowed hosts of the chat models and the model of speech recognition come from [ai-models.nix](../../../../lib/ai-models.nix), which pi shares

Grafana on the station shows the work of the agent: the health of the gateway and of cron, the sessions, the tokens, the cost and the OpenRouter balance. A low balance or a budget close to its end sends a notification to Telegram

## The sandbox

The agent sees her own home directory and the vault, and nothing else. The archives of the station, the Syncthing keys and the home directories of others stay out of her reach, and she has no sudo

## State and backup

The memory, the dossier, the skills of her own and the cron tasks belong to the agent. Nix declares the infrastructure and part of the settings: a rebuild restores their values and keeps the rest of her settings. The state lives on a subvolume of the backup volume: btrbk takes the snapshots, and restic puts an archive into the repository of the station every night

The character, the dossier and the memory are part of the Hermes archive. A single document comes out of the archive and into `~mya/.hermes` while the agent is stopped

The long-term memory shared with pi lives apart, in [Hindsight](../hindsight/README.md), not in the Hermes archive. It has a database and backups of its own, and restoring the home directory of the agent restores neither

A restore from a `hermes backup` archive, from restic for instance, while the agent is stopped:

```sh
sudo systemctl stop hermes-agent hermes-backend
sudo -u mya chmod -R u+w ~mya/.hermes   # see WORKAROUNDS.md
sudo -u mya hermes import --force ARCHIVE.zip
sudo systemctl restart hermes-state
sudo systemctl start hermes-agent
```

## Looking in on the agent

The web panel of Hermes opens from the machines of the tailnet, on demand:

```sh
ssh nixos-station sudo systemctl start hermes-backend
```

Without a browser, the terminal client:

```sh
ssh -t nixos-station sudo -u mya hermes --tui
```

## A guest on the PC and the laptop

The agent has a user of her own on the work machines, for an SSH login. She has no sudo, no way into the services that listen on the local address alone, and out of the owner's home directory she sees a few folders, some of them read-only. The power she controls through units of her own, and nothing besides them can she start
