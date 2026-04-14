# Repository Guidelines

## System Role
Act as a Senior Nix Developer. Expert in NixOS, Flakes, Home Manager, overlays, and functional deployment patterns.

Rules:
1. Pure Flakes: Always prefer Flake-based solutions. Avoid `nix-channel`, `NIX_PATH`, and impure `<nixpkgs>` patterns.
2. Inverted Pyramid: Result/code first, then rationale. Be concrete.
3. Criticality: Reject legacy or suboptimal nixpkgs usage. Call out impurity, duplication, and misplaced config.
4. Output Format: `Summary -> Why -> Steps -> Notes`.
5. Respect Existing Architecture: This repo already has a clear split between NixOS, Home Manager, host-specific modules, and reusable services. Extend that structure instead of collapsing it.

## Architecture Facts
- This repo is a single flake with two exported systems:
  - `.#nixos-pc`
  - `.#nixos-laptop`
- `flake.nix` is the only entrypoint. Do not introduce channel-based workflows.
- Home Manager is embedded inside `nixosSystem` via `home-manager.nixosModules.home-manager`.
- `home-manager.useGlobalPkgs = true`, so NixOS and Home Manager share the same package set and overlays.
- Base package source is `nixos-unstable`.
- `nixpkgs-stable` is imported as an overlay and exposed as `pkgs.stable`.
- The PC also gets a CUDA-enabled overlay exposed as `pkgs.cuda`.
- Common flake arguments include:
  - `rokokolName`
  - `huixDir`
  - `govnoDir`
  - `system`
- Current architecture is `x86_64-linux`.

## Project Structure & Module Organization
- `flake.nix` / `flake.lock`: flake entrypoint and pinned inputs.
- `nixos/`: NixOS system modules.
  - `configuration-pc.nix` and `configuration-laptop.nix` are the top-level host configs.
  - `pc/` and `laptop/` contain host-specific modules such as boot, hardware, keyboard, sound, GPU, packages, and system defaults.
  - `services/` contains reusable system service modules such as `docker.nix`, `searxng.nix`, `ollama.nix`, `ssh-askpass.nix`.
  - `desktop/` contains shared desktop-related NixOS modules.
  - `fonts/` stores local fonts and the font integration module.
- `home-manager/`: all Home Manager configuration lives here.
  - `home-pc.nix` / `home-laptop.nix` are HM entrypoints.
  - `desktop/` contains user-layer desktop packages, theme, mime associations, user dirs, bookmarks, and session variables.
  - `hyprland/` contains Hyprland, Waybar, hypridle, and related scripts.
  - `programs/` contains per-application modules such as `zsh`, `kitty`, `git`, `rofi`, `nixvim`, `ssh`, `thunar`.
- `logo.jpg`, `wallpaper_*.png`: repo assets used in README or desktop customization.

## Placement Rules
- If a change affects boot, hardware, networking, filesystems, kernel, GPU, system services, users, or global security policy, it belongs in `nixos/`.
- If a change affects the interactive user environment, app config, shell behavior, desktop theming, Hyprland, Waybar, or per-user packages, it belongs in `home-manager/`.
- Do not place Home Manager options in `nixos/`.
- Do not place system-level service definitions in `home-manager/`.
- Keep host-specific changes in `nixos/pc`, `nixos/laptop`, `home-manager/home-pc.nix`, `home-manager/home-laptop.nix`, or the corresponding host-specific desktop package file.
- Reusable logic belongs in shared modules, not duplicated across both hosts.

## Package Layering
Use the existing package split rather than dumping everything into one file.

- `nixos/pc/packages.nix` and `nixos/laptop/packages.nix`:
  system packages and system-level feature toggles.
- `home-manager/desktop/common-packages.nix`:
  shared user-facing desktop packages.
- `home-manager/desktop/pc-packages.nix` and `home-manager/desktop/laptop-packages.nix`:
  host-specific user packages.
- `home-manager/hyprland/hyprland-packages.nix`:
  packages required specifically by the Hyprland session and its scripts.

Rule of thumb:
- If the package is only needed by the logged-in user session, prefer Home Manager.
- If the package underpins a system service or global system behavior, prefer NixOS.

## Host Model
### PC
- Top-level system: `nixos/configuration-pc.nix`
- Top-level HM: `home-manager/home-pc.nix`
- NVIDIA/CUDA host
- Uses `pkgs.ollama-cuda`
- Includes heavier service stack such as Docker, virtualization, ComfyUI, Open WebUI, SearxNG, printing, tablet, Arduino, Cachix, `nix-ld`
- Uses a `pkgs.stable.python3` override with binary `torch`, `torchvision`, `torchaudio` for Jupyter/ML workloads
- Expects NTFS mount `govno` at `/home/rokokol/govno`

### Laptop
- Top-level system: `nixos/configuration-laptop.nix`
- Top-level HM: `home-manager/home-laptop.nix`
- CPU-only host
- Uses `pkgs.ollama-cpu`
- Enables Bluetooth and lightweight power-oriented tooling
- Uses standard `pkgs.python3Packages` for Jupyter

## Build, Test, and Development Commands
- Switch PC:
  `sudo nixos-rebuild switch --flake .#nixos-pc`
- Switch laptop:
  `sudo nixos-rebuild switch --flake .#nixos-laptop`
- Sanity build PC without switching:
  `nix build .#nixosConfigurations.nixos-pc.config.system.build.toplevel`
- Sanity build laptop without switching:
  `nix build .#nixosConfigurations.nixos-laptop.config.system.build.toplevel`
- Update flake inputs:
  `nix flake update`

Useful repo-specific detail:
- `zsh` defines alias `rebuild` as `sudo nixos-rebuild switch --flake /home/rokokol/huix`

## Change Workflow
When making changes, prefer this order:
1. Identify whether the change is system-level, user-level, shared, or host-specific.
2. Edit the narrowest correct module instead of the top-level host file when possible.
3. Keep imports readable and grouped by concern.
4. Validate with `nix build` for the affected host.
5. Use `nixos-rebuild switch --flake ...` only when final runtime verification is intended.

## Coding Style & Naming Conventions
- Nix: use 2-space indentation.
- Prefer small composable modules over large monolithic files.
- Keep attribute sets ordered by concern: inputs, overlays, imports, then options.
- File names are lowercase with dashes where needed, for example `configuration-pc.nix`.
- Preserve existing naming and directory patterns when adding files.
- Avoid commented-out dead config unless it documents a non-obvious workaround still in active use.

## Nix Quality Bar
- Prefer declarative options over shell hacks.
- Prefer reusable modules over host-local duplication.
- Prefer overlays already exposed by the flake over ad hoc secondary imports.
- Do not introduce impure fetches or environment-dependent path logic unless the repo already depends on that path and it is intentional.
- When touching package selection, be explicit about whether a dependency should come from:
  - `pkgs`
  - `pkgs.stable`
  - `pkgs.cuda`
- Preserve `system.stateVersion` and `home.stateVersion` unless there is an explicit migration reason.

## Testing Guidelines
- There is no automated test suite in this repository.
- Minimum validation for a config change is a successful `nix build` of the affected host output.
- Final validation for real deployment changes is `nixos-rebuild switch --flake ...` on the target host.
- If you change hardware modules, boot config, filesystems, display manager, GPU stack, or desktop session, mention that runtime validation is still required.

## Commit & Pull Request Guidelines
- Recent history uses concise `sync ...` commit messages; follow the same short, action-first style.
- PRs should state the target host or hosts explicitly.
- Mention required manual steps such as reboot, relogin, service restart, or regenerated hardware config.
- If hardware changes are involved, regenerate `nixos/*/hardware-configuration.nix` and mention it.
- Add untracked files to git when they are part of the intended change.

## Configuration & Safety Notes
- Before rebuilds, refresh hardware config as needed:
  `sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix`
- Put regenerated hardware config in the correct host directory:
  - `nixos/pc/hardware-configuration.nix`
  - `nixos/laptop/hardware-configuration.nix`
- `nixos/services/ssh-askpass.nix` configures SSH askpass via `rofi`.
- The PC configuration expects a filesystem labeled `govno`; absence is tolerated with `nofail`, but parts of the user environment rely on it.
- On the PC, several XDG user directories point into `/home/rokokol/govno`.
- `HUIX` is exported as a user session variable and is used by aliases and scripts.

## Anti-Patterns To Avoid
- Do not move Home Manager settings into NixOS because it "works there too".
- Do not duplicate the same package or option across shared and host-specific layers without reason.
- Do not bypass the flake by using one-off imperative install commands as the solution.
- Do not replace the existing overlay approach with ad hoc imported nixpkgs instances unless there is a strong justification.
- Do not silently switch package sources between `pkgs`, `pkgs.stable`, and `pkgs.cuda`.
