# Workarounds

Things in this repo that exist **only** because something upstream is broken or missing. Each entry says what to run to find out whether it is still needed, and what makes it removable. Nothing here is a design decision — deliberate choices belong in the module they live in, not on this list

Rules for this file: one entry per workaround, and every entry must carry a **mechanical** removal check (a command whose output decides it), never a date

---

## `stable.freecad`

**Where:** `home-manager/desktop/packages/packages.nix` in the shared package group, so both hosts use the stable package set for FreeCAD

**Symptom it prevents:** FreeCAD pulls `python3.14-ifcopenshell-0.8.0`, whose build fails in `IfcCShapeProfileDef.cpp` with `converting to 'boost::optional<double>' from initializer list would use explicit constructor`

**Why it happens:** Boost 1.91 made the converting constructor of `boost::optional` unconditionally explicit, but IfcOpenShell 0.8.0 still initializes the optional radius through aggregate brace initialization. The stable package set builds the same FreeCAD 1.1.3 against Python 3.13 and Boost 1.89 and is available from the binary cache

**Removal check:** build FreeCAD directly from the unstable package set rather than through `home.packages`

```sh
nix build --no-link .#nixosConfigurations.nixos-pc.pkgs.freecad
```

Fails in `IfcCShapeProfileDef.cpp` -> keep `stable.freecad`. Builds clean -> change it back to `freecad`

**Upstream:** [IfcOpenShell#9138](https://github.com/IfcOpenShell/IfcOpenShell/pull/9138) (merged source fix), [NixOS/nixpkgs#563014](https://github.com/NixOS/nixpkgs/pull/563014) (pending nixpkgs patch)

---

## Separate Bambu Studio NVIDIA wrapper

**Where:** `home-manager/desktop/packages/packages.nix` in the workstation package group

**Symptom it prevents:** `(bambu-studio.override { withNvidiaGLWorkaround = true; })` changes the monolithic package derivation even though the option only adds four runtime environment variables. The default package from Cachix can no longer substitute it, so Nix recompiles Bambu Studio in 16 parallel jobs and exhausts system memory

**Why this works:** `symlinkJoin` takes the cached default package and wraps only its executable with the same zink environment. The resulting local derivation contains a shell wrapper and a symlink rather than another C++ build

**Removal check:** inspect the current nixpkgs package expression

```sh
nix eval --raw .#nixosConfigurations.nixos-pc.pkgs.bambu-studio.meta.position \
  | cut -d: -f1 | xargs grep -c symlinkJoin
```

Zero -> keep the separate wrapper. Non-zero -> verify that the upstream `withNvidiaGLWorkaround` branch wraps a shared base derivation, replace this wrapper with the upstream override, and confirm with `nix build --dry-run` that Bambu Studio itself will be fetched rather than built

**Upstream:** [NixOS/nixpkgs#498311](https://github.com/NixOS/nixpkgs/issues/498311) introduced the opt-in NVIDIA workaround

---

## `wayland.windowManager.hyprland.systemd.enable = false`

**Where:** `home-manager/desktop/hyprland/hyprland.nix` — a shared HM module, so it covers both hosts, and both need it since `withUWSM = true` lives in the shared `nixos/desktop/core-options.nix`

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
