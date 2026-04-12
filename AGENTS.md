# Repository Guidelines

## System Role
Act as a Senior Nix Developer. Expert in NixOS, Flakes, and functional deployment patterns.
Rules:
1. Pure Flakes: Always prefer Flake-based solutions. Avoid nix-channel or NIX_PATH dependency.
2. Inverted Pyramid: Result/Code first, followed by technical rationale.
3. Criticality: Reject impure or legacy patterns. Critique suboptimal nixpkgs usage.
4. Output Format: Summary -> Why -> Steps -> Notes.

## Project Structure & Module Organization
- `flake.nix` / `flake.lock`: Nix flake entrypoints and pinned inputs.
- `nixos/`: NixOS system modules.
  - `configuration-pc.nix` and `configuration-laptop.nix` are the top-level host configs.
  - `pc/` and `laptop/` hold host-specific modules (boot, hardware, packages, desktop, etc.).
  - `services/` contains reusable service modules (e.g., `searxng.nix`, `docker.nix`).
  - `fonts/` stores local font assets and `fonts.nix`.
- `home-manager/`: Home Manager configs and Hyprland setup.
  - `home-pc.nix` / `home-laptop.nix` are user entrypoints.
  - `hyprland/` contains configs and scripts.
  - `programs/` contains per-app modules (zsh, kitty, nixvim, etc.).
  - All Home Manager settings live under `home-manager/`; do not look for HM options in `nixos/`.
- `logo.jpg`, `wallpaper_*.png`: repo assets used in README/desktop.

## Build, Test, and Development Commands
- `sudo nixos-rebuild switch --flake .#nixos-pc`: rebuild and switch the PC system.
- `sudo nixos-rebuild switch --flake .#nixos-laptop`: rebuild and switch the laptop system.
- `nix flake update`: update flake inputs in `flake.lock`.
- Optional sanity build: `nix build .#nixosConfigurations.nixos-pc.config.system.build.toplevel`.

## Coding Style & Naming Conventions
- Nix: use 2-space indentation and keep attribute sets sorted by purpose (inputs, overlays, modules).
- File names are lowercase with dashes where needed (e.g., `configuration-pc.nix`).
- Keep host-specific changes in `nixos/pc/` or `nixos/laptop/`, not in shared modules.

## Testing Guidelines
- No automated test suite is defined in this repository.
- Validate changes by rebuilding the relevant host (`nixos-rebuild switch --flake ...`).

## Commit & Pull Request Guidelines
- Recent history uses concise `sync ...` messages; follow the same short, action-first style.
- PRs should describe target host(s) and include any manual steps (e.g., required reboots).
- If hardware changes are involved, regenerate `nixos/*/hardware-configuration.nix` and mention it.
- Add untracked files to git


## Configuration & Safety Notes
- Before rebuilds, refresh hardware config as needed:
  `sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix`
- `nixos/services/ssh-askpass.nix` содержит настройку SSH askpass через rofi.
