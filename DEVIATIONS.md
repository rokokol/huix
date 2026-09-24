# Deviations

Cross-cutting choices in this flake that differ from the obvious arrangement. Each entry preserves why the choice cannot move to a narrower layer, what breaks without it and the condition that would make it worth reconsidering

## The root holds every `ddlc-palette` input to one node

**Where:** `flake.nix` - every `ddlc-*` input carries `inputs.ddlc-palette.follows = "ddlc-palette";` next to the `nixpkgs` one

**Why it differs from the obvious route:** `follows` rewrites an input's own dependency tree, and only the flake that owns that tree may declare it. A child repository can make its `nixpkgs` follow its input, but it cannot make its `ddlc-palette` resolve to a node in whoever consumes it - that node does not exist from where the child is written. This is not a gap to close in the children; the declarations at the root are the mechanism

**What it costs to forget one:** the input pulls its own copy of the palette and the lock holds a suffixed second node. The lock once held five at four revisions (`ddlc-rofi-theme` on `6a2277a`, `ddlc-sddm-theme` on `68eedcf`, two on `7b7300d`, root on its own). A colour corrected in the palette then reaches whichever theme was bumped and leaves the rest on the old hex, defeating the single source of truth invisibly unless somebody reads the lock

**Enforcement:** CI asks the lock for every node whose name starts with `ddlc-palette`

```sh
python3 -c "import json;print([k for k in json.load(open('flake.lock'))['nodes'] if k.startswith('ddlc-palette')])"
```

Anything but `['ddlc-palette']` means a parent is missing its `follows`

**Reconsidered by:** Nix gaining a way for a child flake to bind one of its inputs to the consuming root's node. Until then, the root is the only layer that can state this relationship

## The Hyprland input keeps its own `nixpkgs`

**Where:** `flake.nix` — the `hyprland` input carries no `inputs.nixpkgs.follows`, unlike every other third-party input; `hyprgrass` and `hyprland-plugins` follow `hyprland` for both Hyprland and nixpkgs, and `overlay-hyprland` puts the four packages under their nixpkgs names on both hosts

**Why it differs from the obvious route:** the compositor comes from Hyprland's main branch, because the Lua config lives only there since the release series lost it, and the plugins build against exactly that revision through their `follows`. Hyprland's own cache holds builds made from Hyprland's pinned nixpkgs; a `follows` would change every dependency's hash and turn each update into compiling the compositor, its portal and the hypr* libraries locally. The trade is a second copy of nixpkgs in the lock, seen only by those four packages

**What it costs:** the closure carries Hyprland's mesa and friends beside the system's; on an unstable system the two are days apart and Hyprland's wiki reports the mismatch as a problem for stable systems only. A plugin is built against one Hyprland revision and can fall behind the tip of main, so the three inputs move together and the lock is the only pin: `flake.nix` names no revision

```sh
nix flake update hyprland hyprland-plugins hyprgrass
nix build .#nixosConfigurations.nixos-laptop.pkgs.hyprlandPlugins.{hyprbars,hyprgrass}
```

When a plugin does not build against the tip, hold Hyprland at a revision it does build against, in the lock rather than in the URL: `nix flake lock --override-input hyprland github:hyprwm/Hyprland/<rev>`; the revision hyprgrass's own `flake.lock` names is the usual candidate

**Reconsidered by:** the hyprlang config returning to Hyprland's releases, or a release series carrying the Lua config; then the nixpkgs package and its plugins serve again and the input goes
