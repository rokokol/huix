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

## smartd keeps `notifications.wall.enable = true`

**Where:** `nixos/services/system/smartd.nix`, shared by both hosts

**Symptom it prevents:** with `systembus-notify` as the only notification channel, a failing disk sends no desktop alert. smartd writes the problem to the journal and nothing more

**Why it happens:** the nixpkgs smartd module passes `-M exec <notify script>` to smartd only when `mail`, `wall` or `x11` is on. The condition omits `systembus-notify`, so its `dbus-send` line is in the script, but smartd never runs the script. With `wall` on, smartd runs the script, and the script sends both the wall message and the D-Bus alert

**Removal check:** read the condition in the pinned nixpkgs module

```sh
grep -A1 'notifyOpts =' "$(nix eval --raw .#nixosConfigurations.nixos-pc.pkgs.path)/nixos/modules/services/monitoring/smartd.nix"
```

No `ns.enable` in the condition -> keep `wall`. `ns.enable` is in it -> `wall` becomes a free choice

**Upstream:** not reported yet

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

---

## hyprbars button icons take `bar_text_font`

**Where:** `patches/hyprbars-icon-font.patch`, applied by `overlay-hyprland` in `flake.nix` to the plugin from the `hyprland-plugins` flake, for `home-manager/desktop/hyprland/services/titlebars.nix`

**Symptom it prevents:** the close and fullscreen buttons are Nerd Font glyphs, but hyprbars renders every button icon with the font literal `"sans"` (`barDeco.cpp`, the `renderText` call under `// render icon`), and `bar_text_font` reaches the title only. Which font then draws a private-use glyph is fontconfig's fallback choice among every Nerd Font installed, so the buttons could come out of Doki Nerd Font Mono on one rebuild and DepartureMono on the next

**Why this works:** the patch is one line, the icon call takes `barTextFont` from the plugin's own config the way the title call already does

**Removal check:** look at the plugin's source as the flake ships it

```sh
grep -n '"sans"' "$(nix eval --raw .#nixosConfigurations.nixos-pc.pkgs.hyprlandPlugins.hyprbars.src)/hyprbars/barDeco.cpp"
```

A hit -> keep the patch. No hit -> the plugin renders icons with the configured font; drop the patch and its line in the overlay

**Upstream:** [hyprwm/hyprland-plugins#710](https://github.com/hyprwm/hyprland-plugins/pull/710) (the same change, open)

---

## rofi from its development branch

**Where:** the `rofi` input in `flake.nix` (`ref=next`, with submodules) and `overlay-rofi`, which builds `rofi-unwrapped` from it on both hosts with the nixpkgs recipe; the wrapper and the rofi plugins take the unwrapped package from the overlay. `preVersionCheck` there matches the `2.0.0-dev` the branch reports

**Symptom it prevents:** rofi 2.0.0 on Wayland binds no `wl_touch` and cannot close on a click outside its window: a finger does nothing in the menu the bar button and the bottom-edge swipe open, and the only way out of it is Escape, which a folded laptop has no key for

**Why this works:** `next` carries both: [davatorium/rofi#2336](https://github.com/davatorium/rofi/pull/2336) drives the pointer path from the first finger (a still finger is a click on lift, a moving one scrolls the list), and [6d2a528](https://github.com/davatorium/rofi/commit/6d2a528) covers the screen with a transparent surface that cancels on a press outside the menu, which a tap reaches through the same path. `click-to-exit` is on by default. Tried on the laptop: tap selects, second tap accepts, a swipe scrolls, a tap outside closes

**Removal check:** the first rofi release after 2.0.0 in nixpkgs

```sh
nix eval --impure --raw --expr '(builtins.getFlake (toString ./.)).inputs.nixpkgs.legacyPackages.x86_64-linux.rofi-unwrapped.version'
```

`2.0.0` -> keep the input. A later version -> drop the input and the overlay, then check that a tap selects and a tap outside closes. Until then `nix flake update rofi` moves the branch; `nix build .#nixosConfigurations.nixos-laptop.pkgs.rofi` runs rofi's own tests and is the check for such a bump

**Upstream:** the changes are merged; the entry waits for a release

---

## blueman connects a device on `row-activated`

**Where:** `patches/blueman-row-activated.patch`, applied by `overlay-blueman` in `flake.nix` on the laptop, the host with `services.blueman.enable`

**Symptom it prevents:** in blueman-manager a double tap on a device only selects it; connecting needs a mouse. The device list connects on `button-press-event` and acts only when the event is `_2BUTTON_PRESS` (`ManagerDeviceList.py`, `_on_event_clicked`). GDK emulates a pointer press from each touch, but never a double press, so that branch does not run for a finger, however the taps land: measured with a GTK3 tree view under `WAYLAND_DEBUG`, every tap arrived as a single `button-press` and the double tap arrived only as `row-activated`

**Why this works:** `row-activated` is the tree view's own activation, emitted by its press gesture for a mouse double-click and a double tap alike, and for Enter. The patch moves the connect and disconnect there and leaves the raw handler the right-click menu only. The double tap counts within `gtk-double-click-distance`, which is why `home-manager/desktop/theme/theme.nix` widens it from the stock 5 px to 24

**Removal check:** look at the device list as nixpkgs ships it; the source is a tarball

```sh
tar -xOf "$(nix eval --raw .#nixosConfigurations.nixos-laptop.pkgs.blueman.src)" --wildcards '*/blueman/gui/manager/ManagerDeviceList.py' | grep -c 'row-activated'
```

`0` -> keep the patch. Anything else -> blueman activates rows itself; drop the patch and the overlay, then check that a double tap still connects

**Upstream:** [blueman-project/blueman#3378](https://github.com/blueman-project/blueman/pull/3378) (the same change, open)

---

## The bar's workspaces come from `ext/workspaces`

**Where:** `home-manager/desktop/hyprland/services/waybar/bar.nix`, the `ext/workspaces` module in place of `hyprland/workspaces`, on both hosts

**Symptom it prevents:** against Hyprland's main branch, waybar 0.15.0's `hyprland/workspaces` marks every button active after the bar starts, and a click on a button does nothing. The module reads a workspace's `id` from Hyprland's JSON, which main replaced by `address`, so every id is 0; and it switches with `dispatch workspace N`, which the Lua IPC answers with a syntax error

**Why this works:** `ext/workspaces` speaks the Wayland ext-workspace protocol, which Hyprland implements (`ext_workspace_manager_v1`) and which does not change with the IPC. Hyprland grants `activate` on every inactive workspace and marks the special one hidden, which the module leaves off the bar by default. Tried on the laptop with a second bar: the buttons carry the right names and a click switches the workspace. What it lacks against the Hyprland module is a separate icon for an urgent workspace; the `urgent` class still reaches the CSS

**Removal check:** a waybar release in nixpkgs that carries both [Alexays/Waybar#5013](https://github.com/Alexays/Waybar/pull/5013) (Lua dispatch, merged) and [Alexays/Waybar#5324](https://github.com/Alexays/Waybar/pull/5324) (workspaces by `address`, open)

```sh
nix eval --raw .#nixosConfigurations.nixos-laptop.pkgs.waybar.version
```

`0.15.0` -> keep the module. A later version -> the Hyprland module may come back if its extras are wanted; start a second bar with it, check that one button is active and a click switches, then swap the module name

**Upstream:** [Alexays/Waybar#5324](https://github.com/Alexays/Waybar/pull/5324), open

---

## kitty takes a finger on Wayland

**Where:** `patches/kitty-wayland-touch.patch`, applied by `overlay-kitty` in `flake.nix` to `kitty` on the laptop, the host with a touchscreen

**Symptom it prevents:** kitty builds its own copy of GLFW, and its Wayland backend binds `wl_pointer` and `wl_keyboard` from the seat and never `wl_touch` (`glfw/wl_init.c`, `seatHandleCapabilities`): a finger on the terminal does nothing, neither a tap nor a scroll

**Why this works:** the patch binds `wl_touch` and drives kitty's existing pointer paths from the first finger. A finger that lifts within 8 px is a left click at that place. A finger that moves at once is a finger-based high resolution scroll, the event a touchpad produces, so the text follows it and carries on under kitty's momentum scrolling after it lifts; a sideways finger scrolls sideways, which a program that asked for mouse reports receives as a horizontal wheel. A finger held still for 400 ms before it moves is a left button dragged from where it landed, which selects text. The hold is measured at the first move from the event timestamps, so no timer is needed. A cancel from the compositor releases a held button. Tried on the laptop: taps, scrolls and selections, with the touchpad still working beside them

**Removal check:** look at the backend as nixpkgs ships it

```sh
grep -c 'wl_seat_get_touch' "$(nix eval --raw .#nixosConfigurations.nixos-laptop.pkgs.kitty.src)/glfw/wl_init.c"
```

`0` -> keep the patch. Anything else -> kitty binds touch itself; drop the patch and the overlay, then check a tap, a scroll and a selection

**Upstream:** [kovidgoyal/kitty#10536](https://github.com/kovidgoyal/kitty/pull/10536) (the same change, open)
