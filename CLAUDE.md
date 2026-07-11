# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A single NixOS flake that builds two hosts: `nixos-pc` (NVIDIA/CUDA workstation) and `nixos-laptop` (CPU-only). It is configuration — there is no application code, no test suite, no linter. "Building" the repo means evaluating the flake into a system closure; "running" it means switching to that closure on a NixOS host.

## Build / switch / iterate

```sh
# Switch (requires root, only on the matching host)
sudo nixos-rebuild switch --flake .#nixos-pc
sudo nixos-rebuild switch --flake .#nixos-laptop

# Build without activating — works from any machine, useful for CI-style validation
nix build .#nixosConfigurations.nixos-pc.config.system.build.toplevel
nix build .#nixosConfigurations.nixos-laptop.config.system.build.toplevel

# Evaluate without building (fastest sanity check)
nix eval .#nixosConfigurations.nixos-pc.config.system.build.toplevel.drvPath

# Inputs
nix flake update            # all
nix flake update <input>    # one
```

There is no `nix flake check` target wired up and no per-module test — validation is `nix build` of the host closure.

## Architecture you must internalize

1. **One flake, two systems.** `flake.nix` defines `nixosConfigurations.nixos-pc` and `nixosConfigurations.nixos-laptop`. There is no separate Home Manager deployment — HM is loaded as a NixOS module via `home-manager.nixosModules.home-manager` with `useGlobalPkgs = true`, so the NixOS and HM layers share one package set and overlays.

2. **Three package sources, always be explicit which one you use:**
   - `pkgs` — `nixos-unstable`
   - `pkgs.stable` — `nixos-25.11`, exposed by `overlay-stable` (both hosts)
   - `pkgs.cuda` — `nixos-unstable` with `cudaSupport = true` and `cudaCapabilities = ["8.6"]`, exposed by `overlay-cuda` (PC only)
   Mismatches cause silent rebuilds of huge ML stacks. The PC's Jupyter module deliberately uses `pkgs.stable.python3` with `torch-bin` overrides to avoid building torch from source.

3. **`commonArgs` is the only way arguments cross the flake boundary.** `flake.nix` builds `commonArgs = { rokokolName, huixDir, govnoDir, system, inputs }` and passes it via both `specialArgs` (NixOS) and `extraSpecialArgs` (HM). Any module can pull these out of its arguments — no need to thread them manually. When you add a new constant that multiple modules need, add it here, not as a `let` binding scattered across files.

4. **Host composition is layered. Edit the narrowest layer.**
   - `nixos/configuration-<host>.nix` — the per-host *input*: imports, the one or two settings that genuinely differ (`ollama.package`, `stateVersion`) and the `custom.*.enable` flags for host-specific services.
   - `nixos/default.nix` — modules shared by both hosts (desktop, fonts).
   - `nixos/<host>/` — host-specific hardware/system/boot/keyboard/options.
   - `nixos/services/default.nix` — the single aggregator importing *all* service modules on both hosts. Shared services are unconditional; host-specific ones are gated by `custom.<name>.enable` declared inside their own module. To add/remove a service from a host, flip the flag in `configuration-<host>.nix`.
   - `nixos/services/<category>/` — individual service modules, grouped by `ai/`, `desktop/`, `devices/`, `system/`, `tools/`, `utils/`. New services go into the appropriate category and get imported in `services/default.nix`.
   - Same shape mirrors on the HM side: `home-manager/home-<host>.nix` is the per-host input (all `custom.*` values: hyprland, waybar, packages, dataDir) → shared `desktop/user.nix` → shared `programs/` + `desktop/`.

5. **Custom options are namespaced under `custom.*` and declared in the module they gate.** NixOS side: `custom.jupyter.{enable,withCuda}` plus enable flags for host-specific services (`comfyui`, `openwebui`, `searxng`, `printer`, `tablet`, `virtualCamera`, `virtualization`), set in `configuration-<host>.nix`. HM side: `custom.hyprland.*`, `custom.waybar.*` (one bar, per-feature component files), `custom.packages.{pc,laptop}`, `custom.home.dataDir`, set in `home-<host>.nix`. Follow this pattern — don't reach for `mkIf config.services.foo.enable` from another module to gate behavior; expose an option.

6. **`useGlobalPkgs = true` consequence.** You cannot set `nixpkgs.config` or `nixpkgs.overlays` inside an HM module — they're ignored. All package/overlay config lives in `flake.nix` (system-level).

## Placement rules

When in doubt where a change belongs:

- **NixOS (`nixos/`)** — boot, hardware, networking, kernel, GPU, system-wide services, users, global security, anything touching `/etc` or systemd-system units.
- **Home Manager (`home-manager/`)** — interactive user environment, app config, shell behavior, desktop theming, Hyprland/Waybar, per-user packages, systemd-user units.
- **New system service** — new file in the matching `nixos/services/<category>/`, imported in `nixos/services/default.nix`; if it shouldn't run on both hosts, gate it behind `custom.<name>.enable` and flip the flag in `configuration-<host>.nix`. Do not collapse multiple services into one module.
- **New user app with config** — new file in `home-manager/programs/`.
- Do not cross the streams: no HM options under `nixos/`, no system services under `home-manager/`.

## Package layering

- System packages and feature toggles → host-specific NixOS modules (`nixos/pc/`, `nixos/laptop/`).
- User-facing shared packages → the common block in `home-manager/desktop/packages/packages.nix`.
- Host-specific user packages → the `custom.packages.{pc,laptop}` groups in `packages/packages.nix` (flags set in `home-<host>.nix`).
- Always pick the right source: `pkgs` (unstable default), `pkgs.stable` (stability-critical), `pkgs.cuda` (CUDA workloads on PC).

## Style

- 2-space indentation, kebab-case file names (`configuration-pc.nix`, `wl-clip-persist.nix`).
- **All repo files are kebab-case**, including assets (`assets/just-monika.png`, `assets/ddlc-stickers/dialog-box.png`) — no `snake_case`, `CamelCase`, or spaces. When adding a file, name it kebab-case; when renaming, `git mv` and update every reference (grep the whole tree — refs live in `.nix`, `.sh`, `.conf`, README). Deliberate exceptions: conventional metadata docs (`README.md`, `CLAUDE.md`, `AGENTS.md`, `SKILL.md`, `LICENSE`) and vendored upstream fonts under `nixos/fonts/` (canonical branding; referenced by glob, not by name).
- **Comments in Russian.** Prose comments across scripts and Nix modules are written in Russian; keep new comments Russian and consistent with the surrounding style.
- Small composable modules over monoliths; `default.nix` is reserved for aggregator files that only do `imports = [ ... ]`.
- Prefer flake-pure patterns. Avoid `nix-channel`, `NIX_PATH`, `<nixpkgs>`, and other impure references.
- Declarative over imperative; reusable over duplicated.
- Don't touch `system.stateVersion` / `home.stateVersion` unless doing an explicit migration.

## Editing gotchas

- **`backupFileExtension = "bak-${inputs.self.lastModified}"`** in `flake.nix`. Every rebuild from a different flake revision gets a unique suffix, so old `.bak` files accumulate in `$HOME`. Periodically clean them.
- **Commit your work yourself after each finished change** — a descriptive `git add <files> && git commit` per logical change. Do **not** leave changes for the hourly sync timer: it produces meaningless "sync …" messages and squashes unrelated edits together.
- **The hourly sync timer pushes tracked changes automatically.** `home-manager/desktop/sync.nix` runs `scripts/sync.sh` hourly: `git pull --rebase --autostash` → `git add -u` → `git commit` → `git push`. Note `add -u` (tracked-only) — new untracked files are *not* picked up, so creating a new module and forgetting to `git add` it once will silently leave it out of upstream history. Pull before editing on the other host.
- **`HUIX` env var** points at this repo and is consumed by scripts and aliases. Don't hardcode `/home/rokokol/huix` — use `$HUIX` in scripts and `huixDir` in Nix.
- **PC user dirs depend on the `govno` NTFS mount** at `/home/rokokol/govno`. `xdg.userDirs` (Music/Documents/Pictures/Videos) point there. The mount has `nofail`, so boot survives without it but user paths break.
- **`users.users.${rokokolName}.extraGroups` is set in multiple modules** (`system.nix`, `nvidia.nix`, `docker.nix`, `virtualization.nix`). Nix module merge handles it, but when debugging permissions, grep all of `nixos/` rather than trusting one file.
- **All service ports bind to `127.0.0.1`** (Ollama 11434, Open WebUI 8088, ComfyUI 8188, SearxNG 9000, Jupyter 8888, Syncthing GUI 8384, LibreTranslate 5000) and the firewall opens nothing for them. Don't change a bind address without a deliberate reason; if you must expose something, open the firewall explicitly in the same module.
- **Cachix substituters are declared per-module** (`nixos/pc/nvidia.nix` → cuda-maintainers; `nixos/services/ai/comfyui.nix` → comfyui). When adding a heavy build, prefer adding a substituter over rebuilding.
- **Light/dark theme is owned at runtime, NOT declaratively.** `scripts/toggle-theme.sh` (bind `SUPER+A`) flips `org/gnome/desktop/interface` `color-scheme`+`gtk-theme` in dconf and persists the choice to `~/.local/state/huix/theme`. Do **not** put `color-scheme`/`gtk-theme` in `home-manager/desktop/theme/theme.nix` `dconf.settings`, and do **not** set `gtk.theme` — the HM `gtk` module injects `gtk-theme` into dconf, so `dconf load` on every `nixos-rebuild` would clobber the runtime choice back to light (theme "slips"). The gruvbox theme is installed via `home.packages`. A *static baseline* `gtk-theme-name` is declared via `gtk.gtk3/gtk4.extraConfig` (writes `settings.ini` only, never dconf) so apps that don't use the GtkSettings↔dconf bridge — `swayosd` (systemd-user service), `pavucontrol`, GTK file dialogs — don't fall back to Adwaita; this baseline does *not* follow the runtime toggle. `icon-theme` (non-toggled) is declared in `dconf.settings`. `exec = toggle-theme.sh --sync` in `hyprland.conf` re-applies the saved choice on each reload.
- **Screen zoom differs by input device.** `scripts/zoom.sh` (live magnifier around the cursor via `cursor:zoom_factor`) is bound to `ALT+WIN+wheel` in `hyprland.conf` — but Hyprland `mouse_up`/`mouse_down` binds fire **only for a physical mouse wheel, never a touchpad** (no input option changes this; `emulate_discrete_scroll` does not help). So on the laptop, touchpad zoom is a separate `gesture = 2, pinch, cursorZoom, 1, live` (Hyprland's built-in continuous pinch-zoom — the gesture engine has no generic `exec`, so it can't call `zoom.sh`). Two mechanisms, same feel; keep both.
- **Power button shows a menu, not instant poweroff.** `services.logind.settings.Login.HandlePowerKey = "ignore"` (`nixos/desktop/logind.nix`) hands the power key to Hyprland, which binds `XF86PowerOff` → `scripts/rofi-power.sh` (a rofi script-modi named `power`; its ⚡ prompt emoji comes from `display-power` in `home-manager/programs/rofi/default.nix`, the single source of mode emojis). Without the logind override the system would poweroff immediately, bypassing the menu.
- **Full-screen shaders / software brightness** live in `scripts/screen-shader.sh` (+ `scripts/shaders/*.frag`, `scripts/rofi-shader.sh`); see `scripts/shaders/README.md`. The manager owns Hyprland's single `decoration:screen_shader` slot, composing a **stack of effects** plus brightness into one generated shader (geometric/texture-sampling effects like crt/wave/glitch chained first, colour filters after; multiple geometrics don't stack — single slot). Effects **stack**: the rofi picker (`SUPER+SHIFT+G`) sends `effect toggle` (pick again to remove), `SUPER+G` and picker's «Обычный» send `effect clear`. State (`stack=(...)` + `bright`) is durable in `~/.local/state/huix/shader`; restored by `exec = screen-shader.sh restore` on reload. The waybar indicator (`custom/shader` in `waybar/shader.nix`, both hosts) refreshes via `SIGRTMIN+N` where `N` = `shaderSignal` (defined once in `waybar/shader.nix`, exported as `WAYBAR_SHADER_SIGNAL`). **RT signals' default action is terminate**, so sending one to a not-yet-ready waybar kills it — `restore` suppresses the signal (`SHADER_NO_SIGNAL`); never send it during waybar startup.
- **Notification center** lives in `scripts/notify-center.sh` (+ `scripts/rofi-notify.sh`, waybar module in `waybar/notifications.nix`, both hosts). DND is a mako mode (`[mode=do-not-disturb] invisible=1`) — runtime-only, resets with the mako process, no restore-on-reload needed. The rofi list shows the whole feed as-is; the only per-entry op is copying the text — notification *actions* are deliberately not exposed there (they only work natively on displayed popups: left-click = default action, right-click = `makoctl menu`; `makoctl invoke` on history entries silently no-ops). History is cleared only as a whole (`clear`), and since makoctl has no history-clear command, `clear` restores+dismisses every entry under a second invisible mode (`silent`) so popups don't flash — that's the only use of `silent`. Waybar indicator uses `SIGRTMIN+9` (`WAYBAR_NOTIF_SIGNAL`, declared in `waybar/notifications.nix`; shader owns 8) — same RT-signal rules as above, but here signals only fire on user actions, so no startup suppression is needed. The indicator counts the *feed* = currently displayed popups + history (counting history alone makes on-screen notifications invisible to the counter). Manual close bypasses history (history holds only notifications that expired unseen): popup middle-click via the native `dismiss --no-history` binding action, waybar-module middle-click via `makoctl dismiss -a -h`. **mako never re-reads its config by itself**: it's started by `exec-once` (no systemd unit, no restart on rebuild), so config edits deploy to `~/.config/mako/config` but silently don't apply to the running daemon — `home.activation.reloadMako` in `mako.nix` runs `makoctl reload` on every HM activation to close that gap.
