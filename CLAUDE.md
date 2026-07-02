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
   - `nixos/configuration-<host>.nix` — only imports + the one or two settings that genuinely differ per host (`ollama.package`, `stateVersion`).
   - `nixos/default.nix` — modules shared by both hosts (desktop, fonts).
   - `nixos/<host>/` — host-specific hardware/system/boot/keyboard/options.
   - `nixos/services/services-<host>.nix` — the per-host *list of enabled services*. To add or remove a service from a host, edit this file, not the service module itself.
   - `nixos/services/<category>/` — individual service modules, grouped by `ai/`, `desktop/`, `devices/`, `system/`, `tools/`, `utils/`. New services go into the appropriate category and get imported in the host aggregator.
   - Same shape mirrors on the HM side: `home-manager/home-<host>.nix` → `desktop/user-<host>.nix` → shared `programs/` + `desktop/`.

5. **Custom options are namespaced under `custom.*`.** Today only `custom.jupyter.{enable,withCuda}` exists (see `nixos/services/tools/jupyter.nix`). Follow this pattern — don't reach for `mkIf config.services.foo.enable` from another module to gate behavior; expose an option.

6. **`useGlobalPkgs = true` consequence.** You cannot set `nixpkgs.config` or `nixpkgs.overlays` inside an HM module — they're ignored. All package/overlay config lives in `flake.nix` (system-level).

## Placement rules

When in doubt where a change belongs:

- **NixOS (`nixos/`)** — boot, hardware, networking, kernel, GPU, system-wide services, users, global security, anything touching `/etc` or systemd-system units.
- **Home Manager (`home-manager/`)** — interactive user environment, app config, shell behavior, desktop theming, Hyprland/Waybar, per-user packages, systemd-user units.
- **New system service** — new file in the matching `nixos/services/<category>/`, imported in `services-<host>.nix`. Do not collapse multiple services into one module.
- **New user app with config** — new file in `home-manager/programs/`.
- Do not cross the streams: no HM options under `nixos/`, no system services under `home-manager/`.

## Package layering

- System packages and feature toggles → host-specific NixOS modules (`nixos/pc/`, `nixos/laptop/`).
- User-facing shared packages → `home-manager/desktop/packages/packages-common.nix`.
- Host-specific user packages → `packages-pc.nix` / `packages-laptop.nix`.
- Always pick the right source: `pkgs` (unstable default), `pkgs.stable` (stability-critical), `pkgs.cuda` (CUDA workloads on PC).

## Style

- 2-space indentation, kebab-case file names (`configuration-pc.nix`, `wl-clip-persist.nix`).
- Small composable modules over monoliths; `default.nix` is reserved for aggregator files that only do `imports = [ ... ]`.
- Prefer flake-pure patterns. Avoid `nix-channel`, `NIX_PATH`, `<nixpkgs>`, and other impure references.
- Declarative over imperative; reusable over duplicated.
- Don't touch `system.stateVersion` / `home.stateVersion` unless doing an explicit migration.

## Editing gotchas

- **`backupFileExtension = "bak-${inputs.self.lastModified}"`** in `flake.nix`. Every rebuild from a different flake revision gets a unique suffix, so old `.bak` files accumulate in `$HOME`. Periodically clean them.
- **The hourly sync timer pushes tracked changes automatically.** `home-manager/desktop/sync.nix` runs `scripts/sync.sh` hourly: `git pull --rebase --autostash` → `git add -u` → `git commit` → `git push`. Note `add -u` (tracked-only) — new untracked files are *not* picked up, so creating a new module and forgetting to `git add` it once will silently leave it out of upstream history. Pull before editing on the other host.
- **`HUIX` env var** points at this repo and is consumed by scripts and aliases. Don't hardcode `/home/rokokol/huix` — use `$HUIX` in scripts and `huixDir` in Nix.
- **PC user dirs depend on the `govno` NTFS mount** at `/home/rokokol/govno`. `xdg.userDirs` (Music/Documents/Pictures/Videos) point there. The mount has `nofail`, so boot survives without it but user paths break.
- **`users.users.${rokokolName}.extraGroups` is set in multiple modules** (`system.nix`, `nvidia.nix`, `docker.nix`, `virtualization.nix`). Nix module merge handles it, but when debugging permissions, grep all of `nixos/` rather than trusting one file.
- **All service ports bind to `127.0.0.1`** (Ollama 11434, Open WebUI 8088, ComfyUI 8188, SearxNG 9000, Jupyter 8888, Syncthing GUI 8384, LibreTranslate 5000) and the firewall opens nothing for them. Don't change a bind address without a deliberate reason; if you must expose something, open the firewall explicitly in the same module.
- **Cachix substituters are declared per-module** (`nixos/pc/nvidia.nix` → cuda-maintainers; `nixos/services/ai/comfyui.nix` → comfyui). When adding a heavy build, prefer adding a substituter over rebuilding.
- **Light/dark theme is owned at runtime, NOT declaratively.** `scripts/toggle_theme.sh` (bind `SUPER+A`) flips `org/gnome/desktop/interface` `color-scheme`+`gtk-theme` in dconf and persists the choice to `~/.local/state/huix/theme`. Do **not** put `color-scheme`/`gtk-theme` in `home-manager/desktop/theme/theme.nix` `dconf.settings`, and do **not** set `gtk.theme` — the HM `gtk` module injects `gtk-theme` into dconf, so `dconf load` on every `nixos-rebuild` would clobber the runtime choice back to light (theme "slips"). The gruvbox theme is installed via `home.packages`. A *static baseline* `gtk-theme-name` is declared via `gtk.gtk3/gtk4.extraConfig` (writes `settings.ini` only, never dconf) so apps that don't use the GtkSettings↔dconf bridge — `swayosd` (systemd-user service), `pavucontrol`, GTK file dialogs — don't fall back to Adwaita; this baseline does *not* follow the runtime toggle. `icon-theme` (non-toggled) is declared in `dconf.settings`. `exec = toggle_theme.sh --sync` in `hyprland.conf` re-applies the saved choice on each reload.
- **Full-screen shaders / software brightness** live in `scripts/screen-shader.sh` (+ `scripts/shaders/*.frag`, `scripts/rofi-shader.sh`); see `scripts/shaders/README.md`. The manager owns Hyprland's single `decoration:screen_shader` slot, composing effect+brightness into one generated shader. Durable choice in `~/.local/state/huix/shader`; restored by `exec = screen-shader.sh restore` on reload. The waybar indicator (`custom/shader` in `waybar-pc.nix`) refreshes via `SIGRTMIN+N` where `N` = `shaderSignal` (defined once in `waybar-pc.nix`, exported as `WAYBAR_SHADER_SIGNAL`). **RT signals' default action is terminate**, so sending one to a not-yet-ready waybar kills it — `restore` suppresses the signal (`SHADER_NO_SIGNAL`); never send it during waybar startup.
- **Notification center** lives in `scripts/notify-center.sh` (+ `scripts/rofi-notify.sh`, waybar module in `waybar-notifications.nix`, both hosts). DND is a mako mode (`[mode=do-not-disturb] invisible=1`) — runtime-only, resets with the mako process, no restore-on-reload needed. mako can't delete a single history entry or re-show an arbitrary one, and `makoctl invoke` on history entries silently no-ops — so `delete`/`restore <id>` work via restore/dismiss chains under a second invisible mode (`silent`); don't "simplify" them to direct makoctl calls. Waybar indicator uses `SIGRTMIN+9` (`WAYBAR_NOTIF_SIGNAL`, declared in `waybar-notifications.nix`; shader owns 8) — same RT-signal rules as above, but here signals only fire on user actions, so no startup suppression is needed. Scrolling the module pages through history via a self-replacing `notify-send -r` preview tagged `category=huix-history-preview`: that criterion sets `history=0` (previews never enter history, however they're closed) and re-enables visibility under DND — the DND-bypass section relies on Nix's alphabetical attr ordering to come *after* `mode=do-not-disturb` in the generated config, so don't rename these sections without checking sort order.
