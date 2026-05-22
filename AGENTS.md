# Repository Guidelines

## System Role
Act as a Senior Nix Developer. Expert in NixOS, Flakes, Home Manager, overlays, and functional deployment patterns.

Rules:
1. Pure Flakes: Always prefer Flake-based solutions. Avoid `nix-channel`, `NIX_PATH`, and impure `<nixpkgs>` patterns.
2. Inverted Pyramid: Result/code first, then rationale. Be concrete.
3. Criticality: Reject legacy or suboptimal nixpkgs usage. Call out impurity, duplication, and misplaced config.
4. Output Format: `Summary -> Why -> Steps -> Notes`.
5. Respect Existing Architecture: This repo uses a highly modular structure. Extend it using the established `default.nix` aggregation patterns instead of collapsing it into monolithic files.

## Architecture Facts
- This repo is a single flake with two exported systems:
  - `.#nixos-pc`
  - `.#nixos-laptop`
- `flake.nix` is the only entrypoint.
- Home Manager is embedded inside `nixosSystem` via `home-manager.nixosModules.home-manager`.
- `home-manager.useGlobalPkgs = true`, so NixOS and Home Manager share the same package set and overlays.
- Base package source is `nixos-unstable` (via `nixpkgs`).
- `nixpkgs-stable` is imported as an overlay and exposed as `pkgs.stable`.
- The PC gets a CUDA-enabled overlay exposed as `pkgs.cuda` and has specific CUDA configurations.
- Common flake arguments (`commonArgs`) are passed to all modules (e.g., `rokokolName`, `huixDir`, `govnoDir`, `system`).

## Project Structure & Module Organization
- `flake.nix` / `flake.lock`: flake entrypoint and pinned inputs.
- `nixos/`: NixOS system modules.
  - `configuration-pc.nix` and `configuration-laptop.nix` are the top-level host configs.
  - `pc/` and `laptop/` contain host-specific hardware and system logic.
  - `default.nix` bundles shared desktop and font modules.
  - `services/` contains highly modularized system services categorized by function (e.g., `ai/`, `desktop/`, `system/`, `tools/`). These are aggregated via `services-pc.nix` and `services-laptop.nix`.
- `home-manager/`: Home Manager configurations.
  - `home-pc.nix` / `home-laptop.nix` are HM entrypoints.
  - `desktop/` contains user-layer desktop logic, including environments like `hyprland/`, `waybar/`, `theme/`, and user packages.
  - `programs/` contains modular configurations for tools like `nixvim`, `zsh`, `git`, etc.
- `scripts/`: Centralized directory for custom shell scripts.

## Placement Rules
- **NixOS (`nixos/`)**: Changes affecting boot, hardware, networking, kernel, GPU, system-wide services, users, or global security.
- **Home Manager (`home-manager/`)**: Changes affecting the interactive user environment, app config, shell behavior, desktop theming, Hyprland, Waybar, or per-user packages.
- **Services**: New system services go into the appropriate subfolder in `nixos/services/` and must be imported in the corresponding `services-<host>.nix` file.
- **Programs**: New user applications with configuration go into `home-manager/programs/`.
- Do not cross the streams: No HM options in `nixos/`, no system services in `home-manager/`.

## Package Layering
Use the existing package split:
- System packages and feature toggles belong in the host-specific modules (e.g., `nixos/pc/`).
- User-facing shared packages belong in `home-manager/desktop/` (or related subfolders).
- Host-specific user packages belong in their respective HM package definitions.
- Always be explicit about the source:
  - `pkgs` (default unstable)
  - `pkgs.stable` (for stability-critical tools)
  - `pkgs.cuda` (for ML/AI workloads on the PC)

## Host Model
### PC (`nixos-pc`)
- NVIDIA/CUDA host.
- Uses `pkgs.cuda` for heavy AI/ML and creative workloads (Ollama, ComfyUI, Darktable, OBS, etc.).
- Heavy service stack (Docker, SearxNG, virtualization).
- Expects NTFS mount `govno` at `/home/rokokol/govno`. Many user directories map here.

### Laptop (`nixos-laptop`)
- CPU-only host.
- Lightweight, power-oriented configuration.
- Uses standard CPU packages (e.g., `pkgs.ollama-cpu`).

## Build & Test Commands
- Switch PC: `sudo nixos-rebuild switch --flake .#nixos-pc` (or `rebuild` alias).
- Switch Laptop: `sudo nixos-rebuild switch --flake .#nixos-laptop`
- Build PC (no switch): `nix build .#nixosConfigurations.nixos-pc.config.system.build.toplevel`
- Build Laptop (no switch): `nix build .#nixosConfigurations.nixos-laptop.config.system.build.toplevel`
- Update specific input: `nix flake lock --update-input <name>`

## Change Workflow
1. Identify scope: system vs user, shared vs host-specific.
2. Edit the narrowest correct module. Create new modules in the appropriate category folder (e.g., `nixos/services/ai/`) rather than bloat existing ones.
3. Import new modules using the `default.nix` pattern or specific aggregator files (`services-pc.nix`).
4. Validate with `nix build`.

## Coding Style
- 2-space indentation.
- Small composable modules over monoliths.
- Order: inputs -> overlays -> imports -> options.
- Kebab-case file names (`configuration-pc.nix`).

## Quality Bar
- Declarative over imperative.
- Reusable over duplicated.
- Explicit package sources (`pkgs`, `pkgs.stable`).
- Keep `system.stateVersion` untouched unless migrating.
