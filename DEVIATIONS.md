# Deviations

Permanent cross-cutting choices in this flake that differ from the obvious arrangement. Each entry preserves why the choice cannot move to a narrower layer and what breaks without it. An arrangement that an upstream change could retire belongs in `WORKAROUNDS.md`

---

## The root holds every `ddlc-palette` input to one node

**Where:** `flake.nix` — every `ddlc-*` input carries `inputs.ddlc-palette.follows = "ddlc-palette";` next to the `nixpkgs` one

**Why it differs from the obvious route:** `follows` rewrites an input's own dependency tree, and only the flake that owns that tree may declare it. A child repository can make its `nixpkgs` follow its input, but it cannot make its `ddlc-palette` resolve to a node in whoever consumes it — that node does not exist from where the child is written. This is not a gap to close in the children; the declarations at the root are the mechanism

**What returning to the obvious route breaks:** an input without the line pulls its own copy of the palette and the lock holds a suffixed second node. The lock once held five at four revisions (`ddlc-rofi-theme` on `6a2277a`, `ddlc-sddm-theme` on `68eedcf`, two on `7b7300d`, root on its own). A colour corrected in the palette then reaches whichever theme was bumped and leaves the rest on the old hex, defeating the single source of truth invisibly unless somebody reads the lock

**Enforcement:** CI asks the lock for every node whose name starts with `ddlc-palette`

```sh
python3 -c "import json;print([k for k in json.load(open('flake.lock'))['nodes'] if k.startswith('ddlc-palette')])"
```

Anything but `['ddlc-palette']` means a parent is missing its `follows`
