# Workarounds

Things in this repo that exist **only** because something upstream is broken or missing. Each entry says what to run to find out whether it is still needed, and what makes it removable. Nothing here is a design decision — deliberate choices belong in the module they live in, not on this list

Rules for this file: one entry per workaround, and every entry must carry a **mechanical** removal check (a command whose output decides it), never a date

---

## `wayland.windowManager.hyprland.systemd.enable = false`

**Where:** `home-manager/desktop/hyprland/hyprland.nix`

**Symptom it prevents:** logging into the `Hyprland (uwsm)` session shows the cursor on a black screen for ~2 seconds, then drops back to SDDM, forever. The plain `Hyprland` session entry is unaffected

**Why it happens:** HM's hyprland module appends `systemctl --user stop hyprland-session.target` to the `exec-once` it generates. That target declares:

```
BindsTo=graphical-session.target
PropagatesStopTo=graphical-session.target
```

uwsm's `wayland-session@.target` in turn declares `BindsTo=graphical-session.target`, and the compositor unit `wayland-wm@hyprland.desktop.service` declares `BindsTo=wayland-session@%i.target`. So the stop cascades all the way into the compositor. In the journal this looks like a **clean stop job** — `Stopped Main service for Hyprland` plus `Triggering OnSuccess=`, no `Main process exited`, and the Hyprland log in `/run/user/1000/hypr/<sig>/hyprland.log` just ends mid-render with no backtrace. Easy to misread as a GPU or driver fault; it is neither. Plain Hyprland survives because there the compositor is a bare process, not a systemd unit, so nothing is bound to the target

**Why turning it off is free:** Hyprland does the same work natively — it links `libsystemd` and on startup runs

```
systemctl --user import-environment DISPLAY WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP QT_QPA_PLATFORMTHEME PATH XDG_DATA_DIRS
  && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE …
```

and sends `sd_notify(READY=1)` unless `HYPRLAND_NO_SD_NOTIFY` is set. That is exactly what uwsm needs: its `waitenv` waits for `WAYLAND_DISPLAY` + `HYPRLAND_INSTANCE_SIGNATURE`, and the `Type=notify` compositor unit needs the readiness signal. So **no `uwsm finalize` line in `exec-once` is needed** — an earlier attempt added one, it was a duplicate, it was removed

**Rejected alternative:** `systemd.extraCommands = [ ]` disables only the destructive half and keeps HM's env export. It works, but leaves a `hyprland-session.target` nothing ever starts, an `exec-shutdown` that stops it, and a second copy of an export Hyprland already does

**Removal check:**

```sh
# the conflict stands as long as HM's module has no idea uwsm exists
grep -ric uwsm "$(nix eval --raw '.#nixosConfigurations.nixos-pc.config.home-manager.extraSpecialArgs.inputs.home-manager.outPath' 2>/dev/null)/modules/services/window-managers/hyprland/"
```

Zero hits → keep the line. Once it is non-zero, read what HM does now, then drop the option and test a real `Hyprland (uwsm)` login. If that login loops again:

```sh
journalctl -b 0 | grep uwsm_waitenv   # shows which variable never arrived
```

Note Hyprland's own flake does not change any of this: its `homeManagerModules.default` only sets `package` and defers to HM's module for everything else

**Upstream:** [NixOS UWSM wiki](https://wiki.nixos.org/wiki/UWSM) (says to disable the integration), [hyprwm/Hyprland#9265](https://github.com/hyprwm/Hyprland/issues/9265)

---

## `overlay-tauon` — appindicator on tauon's `LD_LIBRARY_PATH`

**Where:** `flake.nix`

**Symptom it prevents:** with the tray enabled (`settings` > `View` > `Tray`, or `--tray` — the pref is off by default) tauon dies on startup, not just losing the icon:

```
RuntimeError: SDL_CreateTray failed: Could not load AppIndicator libraries
```

**Why it happens:** since 11.1.1 the tray goes through SDL3's `SDL_CreateTray()` instead of pygobject, and SDL loads the indicator library at runtime with `dlopen()` by soname — `libayatana-appindicator3.so.1` first, then `libappindicator3.so.1`. nixpkgs lists `libappindicator` in `buildInputs` only, which reaches `GI_TYPELIB_PATH` (the typelib the tray no longer uses) and never the wrapper's `LD_LIBRARY_PATH`. So the library sits in the closure and stays invisible to `dlopen`

gtk3 deliberately gets no such treatment even though SDL dlopens `libgtk-3.so.0` too: `SDL_CreateTray()` calls `init_appindicator()` first, and the indicator library pulls its own gtk3 in through RPATH, so the soname is already in the link map

**Removal check:** build tauon as nixpkgs has it, with no overlay in the way, and look for an appindicator on its `LD_LIBRARY_PATH`

```sh
grep -o "LD_LIBRARY_PATH='[^']*'" \
  "$(nix build --no-link --print-out-paths --impure --expr \
    'let f = builtins.getFlake (toString ./.); in f.inputs.nixpkgs.legacyPackages.x86_64-linux.tauon')/bin/tauon" \
  | grep -c appindicator
```

Prints `0` → keep the overlay. Non-zero → drop `overlay-tauon` from `flake.nix` and from both host overlay lists

**Upstream:** [NixOS/nixpkgs#549538](https://github.com/NixOS/nixpkgs/issues/549538) (the bug), [NixOS/nixpkgs#549863](https://github.com/NixOS/nixpkgs/pull/549863) (our fix), [NixOS/nixpkgs#96420](https://github.com/NixOS/nixpkgs/issues/96420) (the standing "stop using dead libappindicator" issue it feeds)

---

## `overlay-hyprland` — glaze pinned to 7.2.0

**Where:** `flake.nix` — and it must sit in the overlay list of **both** hosts, since both run Hyprland. It was on `nixos-pc` only for a while, which left `nixos-laptop` unbuildable

**Why:** nixpkgs carries `glaze` 8.0.0, which hyprland 0.56.1 does not build against, so the overlay pins hyprland's `glaze` **back** to 7.2.0 from GitHub. Note this is a downgrade — a newer nixpkgs `glaze` is therefore not by itself evidence the overlay can go. Without it the build fails like this, because hyprland's CMake falls back to fetching glaze over the network and the sandbox has no git:

```
-- glaze dependency not found, retrieving v7.2.0 with FetchContent
CMake Error: error: could not find git for clone of glaze
```

**Removal check:** build hyprland as nixpkgs has it, with no overlay in the way

```sh
nix build --no-link --impure --expr \
  'let f = builtins.getFlake (toString ./.); in f.inputs.nixpkgs.legacyPackages.x86_64-linux.hyprland'
```

Builds clean → drop `overlay-hyprland` from `flake.nix` and from the `nixos-pc` overlay list. Still fails on `glaze` → keep it, and bump the pinned tag only if hyprland itself moved on
