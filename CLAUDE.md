# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository

## What this repo is

A single NixOS flake that builds two hosts: `nixos-pc` (NVIDIA/CUDA workstation) and `nixos-laptop` (CPU-only). It is configuration — there is no application code, no test suite, no linter. "Building" the repo means evaluating the flake into a system closure; "running" it means switching to that closure on a NixOS host

Every layer has a README in Russian describing what lives there — [`nixos/`](nixos/README.md), [`nixos/services/`](nixos/services/README.md), [`home-manager/`](home-manager/README.md), [`hyprland/`](home-manager/desktop/hyprland/README.md), [`waybar/`](home-manager/desktop/hyprland/services/waybar/README.md), [`programs/`](home-manager/programs/README.md), [`scripts/`](scripts/README.md). Read the one next to the file you are editing; this file holds only what none of them can say

## Build / switch / iterate

```sh
# Switch (requires root, only on the matching host)
sudo nixos-rebuild switch --flake .#nixos-pc
sudo nixos-rebuild switch --flake .#nixos-laptop

# Build without activating — works from any machine, useful for CI-style validation
nix build .#nixosConfigurations.nixos-pc.config.system.build.toplevel

# Evaluate without building (fastest sanity check, and what CI runs)
nix eval .#nixosConfigurations.nixos-pc.config.system.build.toplevel.drvPath

# Inputs
nix flake update            # all
nix flake update <input>    # one
```

There is no `checks` output, no `formatter` and no per-module test — `nix flake check` proves nothing here and `nix fmt` does not run. Validation is `nix build` of the host closure; both gaps are written up under "Deferred" in `workarounds.md`

## Architecture you must internalize

1. **One flake, two systems.** `flake.nix` defines `nixosConfigurations.nixos-pc` and `nixosConfigurations.nixos-laptop`. There is no separate Home Manager deployment — HM is loaded as a NixOS module with `useGlobalPkgs = true`, so both layers share one package set and overlays. The consequence: `nixpkgs.config` and `nixpkgs.overlays` set inside an HM module are **ignored**, so all package and overlay config lives in `flake.nix`

2. **Two package sources, always be explicit which one you use.** `pkgs` is `nixos-unstable`; `pkgs.stable` is the last release, exposed by `overlay-stable` on both hosts. Mixing them silently rebuilds huge ML stacks. CUDA workloads come from dedicated attrs (`ollama-cuda`, `btop-cuda`, the `comfyui-nix` flake), never a global `cudaSupport` overlay — `cudaCapabilities = [ "8.6" ]` in `nixpkgsConfig` narrows codegen to this GPU without enabling it, and only `ollama-cuda` honors the flag

3. **`commonArgs` is the only way arguments cross the flake boundary.** `flake.nix` builds it (`rokokolName`, `huixDir`, `govnoDir`, `myWikiDir`, `palette`, `base16`, `system`, `inputs`) and passes it via both `specialArgs` (NixOS) and `extraSpecialArgs` (HM), so any module can pull them out of its arguments. A new constant that several modules need goes here, not into a `let` scattered across files

4. **Host composition is layered. Edit the narrowest layer.**
   - `nixos/configuration-<host>.nix` — the per-host _input_: imports, the settings that genuinely differ (`ollama.package`, `stateVersion`) and the `rokokol.*.enable` flags
   - `nixos/default.nix` — shared by both hosts; `nixos/<host>/` — hardware and host-specific options
   - `nixos/services/default.nix` — the single aggregator importing _all_ service modules on both hosts. Shared services are unconditional; host-specific ones are gated by `rokokol.<name>.enable` declared in their own module. Adding or removing a service from a host means flipping that flag in `configuration-<host>.nix`, not editing the module
   - the same shape mirrors on the HM side: `home-manager/home-<host>.nix` is the per-host input (every `rokokol.*` value) → shared `desktop/user.nix` → `programs/` + `desktop/`

5. **Custom options are namespaced under `rokokol.*` and declared in the module they gate.** Don't reach for `mkIf config.services.foo.enable` from another module to gate behavior — expose an option instead. Modules of the extracted flakes keep their own namespaces (`ddlc.*`, `programs.screen-shader.*`, `services.virtual-media-devices.*`); do not wrap those in a `rokokol.*` alias

## Placement rules

- **NixOS (`nixos/`)** — boot, hardware, networking, kernel, GPU, system-wide services, users, global security, anything touching `/etc` or systemd-system units
- **Home Manager (`home-manager/`)** — interactive user environment, app config, shell behavior, desktop theming, Hyprland/Waybar, per-user packages, systemd-user units
- **New system service** — new file in the matching `nixos/services/<category>/` (`ai/`, `desktop/`, `devices/`, `system/`, `tools/`, `utils/`), imported in `nixos/services/default.nix`; gate it behind `rokokol.<name>.enable` if it shouldn't run on both hosts. Do not collapse multiple services into one module
- **New user app with config** — new file in `home-manager/programs/`
- Do not cross the streams: no HM options under `nixos/`, no system services under `home-manager/`

Package layering follows the same split: system packages and feature toggles in `nixos/pc/` or `nixos/laptop/`, shared user packages in the common block of `home-manager/desktop/packages/packages.nix`, host-specific user packages in its `rokokol.packages.{pc,laptop}` groups

## Style

The global rules (straight quotes, one-line comments, no trailing period, no hard-wrapped Markdown) apply here too and are not repeated. This repo adds:

- 2-space indentation in `.nix` files. Nothing enforces it — there is no `formatter`, so `nix fmt` cannot check the tree
- **All repo files are kebab-case**, including assets — no `snake_case`, `CamelCase` or spaces. When renaming, `git mv` and grep the whole tree for references (they live in `.nix`, `.sh`, `.conf`, README). Deliberate exceptions: conventional metadata docs (`README.md`, `CLAUDE.md`, `LICENSE`) and the vendored fonts under `nixos/fonts/`, which are canonical branding and referenced by glob
- **All text is English** — prose comments and every user-facing string (notify-send, rofi prompts, `usage()`, waybar tooltips). The sole exception is `README.md` files, which stay in Russian
- **No dates in comments.** Don't anchor a comment to a moment ("removed on 2026-07-22") — state the durable reason instead ("removed from nixpkgs because it needed GTK2"). Version pins live in `flake.lock`, not in prose
- Small composable modules over monoliths; `default.nix` is reserved for aggregators that only do `imports = [ ... ]`
- Prefer flake-pure patterns — no `nix-channel`, `NIX_PATH`, `<nixpkgs>`
- Don't touch `system.stateVersion` / `home.stateVersion` unless doing an explicit migration

## Committing

- **Commit your work yourself after each finished change** — a descriptive `git add <files> && git commit` per logical change. Do **not** leave changes for the sync service: it produces meaningless "sync …" messages and squashes unrelated edits together
- **Prefix the subject with the current host**: `[nixos-pc] enable CUDA cache`, `[nixos-laptop] add lid mode toggle`
- **The sync service pushes tracked changes after every `nixos-rebuild`** (`home-manager/desktop/sync.nix` → `scripts/sync.sh`): `git pull --rebase --autostash` → `git add -u` → `git commit` → `git push`. Note `add -u` — a new file left without `git add` is silently never pushed. Pull before editing on the other host, and expect a rebuild mid-session to swallow anything you left uncommitted

## Editing gotchas

- **`backupFileExtension = "bak"`** in `flake.nix` is deliberately a fixed string — a `lastModified` suffix rebuilt the HM generation on every commit and littered `$HOME` with one `.bak` set per revision. The cost: a second collision on the same path aborts activation until the stale `.bak` is deleted by hand. For a file some app re-creates, set `force = true` on the `home.file` entry instead of relying on backups
- **Repo assets that a derivation consumes go through `inputs.self`, always isolated via `builtins.path`**: `src = builtins.path { name = "my-assets"; path = "${inputs.self}/assets/..."; };`. A bare `"${inputs.self}/assets/..."` ties the derivation hash to the whole repository, so every commit triggers a rebuild and re-download. The rule is about **derivation inputs only** — `imports = [ "${inputs.self}/scripts/scripts.nix" ]` needs no wrapping, because a module is read at eval time and only the values it produces reach any derivation (verified: an unrelated edit leaves `toplevel.drvPath` byte-identical)
- **`HUIX` / `huixDir` are runtime references to the live checkout**, consumed by scripts, aliases and `source` includes. Don't hardcode `/home/rokokol/huix`. But as a string, `"${huixDir}/…"` is **not** copied into the store, so it is useless for anything a build reads — and unusable in `imports`, where an absolute path is forbidden under pure evaluation
- **Third-party flakes must reuse the system `nixpkgs` and `home-manager` via `follows`** — otherwise the input pulls its own copy of nixpkgs, duplicating packages and downloads. The `ddlc-*` inputs additionally need `inputs.ddlc-palette.follows`, or the colours diverge silently (see `workarounds.md`)
- **The myWiki vault is `myWikiDir` = `$HOME/myWiki` on both hosts**, never derived from `rokokol.home.dataDir`. The path must stay host-invariant: Syncthing carries symlinks verbatim, so anything pointing into the vault would dangle on the other host if the hosts disagreed
- **`users.users.${rokokolName}.extraGroups` is set in several modules** (`system.nix`, `nvidia.nix`, `docker.nix`, `virtualization.nix`, and the virtual-camera seam). Nix merges them, but when debugging permissions grep all of `nixos/` rather than trusting one file
- **All service ports bind to `127.0.0.1`** and the firewall opens nothing for them. Each port is declared once in its module and exported as a session variable — take it from there rather than repeating the number. If you must expose something, open the firewall explicitly in the same module
- **Cachix substituters are declared per-module** (`nixos/pc/nvidia.nix` → cuda-maintainers; `nixos/services/ai/comfyui.nix` → comfyui). When adding a heavy build, prefer adding a substituter over rebuilding
- **Light/dark theme is owned at runtime, NOT declaratively.** `scripts/toggle-theme.sh` (`SUPER+A`) flips dconf and persists the choice to `~/.local/state/huix/theme`. Do **not** put `color-scheme`/`gtk-theme` into `theme.nix` `dconf.settings` and do **not** set `gtk.theme` — the HM `gtk` module writes `gtk-theme` into dconf, so `dconf load` on every rebuild would clobber the runtime choice. The static `gtk-theme-name` baseline in `gtk.gtk3/gtk4.extraConfig` writes `settings.ini` only and deliberately does not follow the toggle. libadwaita apps ignore it entirely and read `~/.config/gtk-4.0/gtk.css`, which the script symlinks to the colour definitions alone (never the full sheet — the parse cost is ~15ms against 0.12ms, and colours are all libadwaita honours). Paths come from `GTK4_LIGHT_CSS`/`GTK4_DARK_CSS` in `home.sessionVariables`, so changing them needs a fresh login before the toggle sees them
- **mako never re-reads its config by itself**, and nothing restarts it on a rebuild — HM's `services.mako` creates no unit at all. The daemon is the package's own `Type=dbus` `mako.service`, started by `exec-once = systemctl --user start mako.service`; a bare `exec-once = mako` would grab the bus name outside systemd. Reloading is already handled by the module's `onChange = "makoctl reload"` — do **not** add a `home.activation.*` reload beside it, and know that `makoctl reload` against a missing config silently resets the daemon to stock defaults and still exits 0
- **Every mako colour must be set in the global block**, never only inside an `[urgency=…]` section. There is no criterion for "sender omitted the urgency hint", and Telegram and Firefox both omit it — such notifications match no section and keep mako's stock blue
- **Screen zoom differs by input device.** `scripts/zoom.sh` is bound to `ALT+WIN+wheel`, but Hyprland `mouse_up`/`mouse_down` binds fire only for a physical wheel, never a touchpad — no input option changes this. The laptop therefore has a separate `gesture = 2, pinch, cursorZoom` (the gesture engine has no generic `exec`, so it cannot call the script). Two mechanisms, same feel; keep both
- **The power button shows a menu, not an instant poweroff** — `HandlePowerKey = "ignore"` in `nixos/desktop/logind.nix` hands the key to Hyprland. **Lid mode on the laptop is an inhibitor lock**, effective only because `nixos/laptop/logind.nix` sets `LidSwitchIgnoreInhibited = "no"`; `HandleLidSwitch` stays at `suspend` on purpose, so the lid still suspends outside the Hyprland session. Both are documented in [hyprland/README](home-manager/desktop/hyprland/README.md)
- **Workarounds that exist only because of an upstream bug live in `workarounds.md`**, one entry each with a mechanical removal check. Add new ones there, and check it before "cleaning up" a line that looks pointless

## Extracted flakes

Ten pieces that outgrew the config live in their own repos (`rokokol/hyprland-screen-shader`, `claude-account`, `rofi-wooordhunt`, `virtual-media-devices`, and the `ddlc-*` family) and come back as flake inputs. Each keeps exactly **one seam** here — a file that enables the module and supplies what it ships none of, nothing more. Before adding an option to a seam, read the comment at its top: each records what the module already owns, because every one of them has been broken once by adding such a line back. The rest is the module's own README

Two rules cross the seams. Colours are not chosen in this repo at all — they arrive through `commonArgs.palette` / `commonArgs.base16`, and a bare hex in a module is a reason to ask why it isn't from there. And the lock command comes from `ddlc.hyprlock.lockCommand`, which `services/hypridle.nix` reads: the dialog engine has to be hyprlock's **parent**, so nothing may call `hyprlock` directly and no bind may call the engine — every lock path goes through `loginctl lock-session`
