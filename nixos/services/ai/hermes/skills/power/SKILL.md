---
name: power
description: Wake the owner's PC, or put the PC or the laptop to sleep, lock it, turn its screen off, shut it down or restart it. Use when the owner asks for any of these, in any words — "включи комп", "разбуди ПК", "усыпи комп", "заблокируй ноут", "погаси экран", "выключи ПК", "перезагрузи ноутбук", "wake my PC" — and when you decide on your own that a workstation should wake, sleep or lock
---

# power

The workstations are `nixos-pc` and `nixos-laptop` on the tailnet. On each you log in as yourself, and you may start one unit per action and no other:

| Action | Unit | What the owner sees |
| --- | --- | --- |
| Sleep | `mya-power-suspend.service` | the host sleeps; the PC wakes only by `wake-pc`, the laptop only by hand |
| Lock | `mya-power-lock.service` | the lock screen, the session kept |
| Screen off | `mya-power-screen-off.service` | a dark screen until the next key or mouse move |
| Shut down | `mya-power-poweroff.service` | the host off |
| Restart | `mya-power-reboot.service` | the host restarts, and any unsaved work is lost |

```sh
ssh HOST systemctl start UNIT
```

1. Sleep, shut down and restart wait until the owner is away: their units refuse while any of his sessions on the host is in use. `ssh HOST mya-power-idle` answers before you try, naming the busy sessions. A desktop counts as idle once it has had no input for ten minutes
2. A host that gives no answer to `tailscale ping -c 1 --timeout 3s HOST` is already asleep or off. Say so rather than trying
3. To wake the PC, run `wake-pc` on the station. It says when the PC is already on, sends the magic packet otherwise and waits for the PC up to five minutes; `wake-pc help` explains its output and exit codes. No answer means the PC may have no power, or its boot stopped before the network came up. The laptop has no wired link and its Wi-Fi does not wake it, so only the owner can wake it
4. You may act without being asked, which is the point of the skill: put the PC to sleep at night, lock a workstation left open, wake the PC for a job that needs it
5. A sleep, a shutdown or a restart drops your SSH connection, so the command may end with an error after it did its work. Check with `tailscale ping` a minute later, not by the exit status
6. Tell the owner in the chat what you did, on which host and why, whenever you acted on your own
