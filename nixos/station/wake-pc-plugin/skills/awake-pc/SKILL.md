---
name: awake-pc
description: Wake the owner's PC over the LAN and report once it is up. Use when the owner asks to wake, turn on or start the PC, in any words — "включи комп", "разбуди ПК", "запусти компьютер", "wake my PC"
---

# awake-pc

The PC is `nixos-pc` on the tailnet. It answers a tailnet ping only while it runs

1. If `tailscale ping -c 1 --timeout 3s nixos-pc` already answers, reply that the PC is on, and stop
2. Run `wake-pc`. It sends a magic packet to the PC's card on the LAN. If it fails, reply with its output, and stop
3. Wait for the PC, up to five minutes:

   ```sh
   timeout 300 sh -c 'until tailscale ping -c 1 --timeout 3s nixos-pc >/dev/null 2>&1; do sleep 10; done'
   ```

4. Reply on the channel the request came from. When the PC answered, say so and how long it took. When it did not, say that it gave no answer in five minutes: it may have no power, or its boot may have stopped before the network came up
