# Workarounds

Things in this repo that exist **only** because something upstream is broken or missing. Each entry says what to run to find out whether it is still needed, and what makes it removable. Nothing here is a design decision — deliberate choices belong in the module they live in, not on this list

Rules for this file: one entry per workaround, and every entry must carry a **mechanical** removal check (a command whose output decides it), never a date

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

## `overlay-tauon` — appindicator on tauon's `LD_LIBRARY_PATH`

**Where:** `flake.nix`

**Symptom it prevents:** with the tray enabled (`settings` > `View` > `Tray`, or `--tray` — the pref is off by default) tauon dies on startup, not just losing the icon:

```
RuntimeError: SDL_CreateTray failed: Could not load AppIndicator libraries
```

**Why it happens:** since 11.1.1 the tray goes through SDL3's `SDL_CreateTray()` instead of pygobject, and SDL loads the indicator library at runtime with `dlopen()` by soname — `libayatana-appindicator3.so.1` first, then `libappindicator3.so.1`. nixpkgs lists `libappindicator` in `buildInputs` only, which reaches `GI_TYPELIB_PATH` (the typelib the tray no longer uses) and never the wrapper's `LD_LIBRARY_PATH`. So the library sits in the closure and stays invisible to `dlopen`

gtk3 deliberately gets no such treatment even though SDL dlopens `libgtk-3.so.0` too: `SDL_CreateTray()` calls `init_appindicator()` first, and the indicator library pulls its own gtk3 in through RPATH, so the soname is already in the link map

**Removal check:** build tauon as nixpkgs has it, with no overlay in the way, and look for an appindicator on its `LD_LIBRARY_PATH`

```sh
grep -o "LD_LIBRARY_PATH='[^']*'" \
  "$(nix build --no-link --print-out-paths --impure --expr \
    'let f = builtins.getFlake (toString ./.); in f.inputs.nixpkgs.legacyPackages.x86_64-linux.tauon')/bin/tauon" \
  | grep -c appindicator
```

Prints `0` → keep the overlay. Non-zero → drop `overlay-tauon` from `flake.nix` and from both host overlay lists

**Upstream:** [NixOS/nixpkgs#549538](https://github.com/NixOS/nixpkgs/issues/549538) (the bug), [NixOS/nixpkgs#549863](https://github.com/NixOS/nixpkgs/pull/549863) (our fix), [NixOS/nixpkgs#96420](https://github.com/NixOS/nixpkgs/issues/96420) (the standing "stop using dead libappindicator" issue it feeds)

---

## `overlay-jupyterlab` — expand `$out` in `JUPYTERLAB_DIR`

**Where:** `flake.nix`, in the overlay list of **both** hosts (`services.jupyter` runs on the PC, but `python3Packages.jupyterlab` is reachable on either)

**Symptom it prevents:** the login page works, but every `/lab` request 500s with

```
JupyterLab application assets not found in "/home/rokokol/$out/share/jupyter/lab"
jinja2.exceptions.TemplateNotFound: 'index.html'
```

The `$out` is literal, and the relative path is resolved against the unit's `WorkingDirectory=~`

**Why it happens:** nixpkgs writes the app dir as an unquoted shell variable

```nix
makeWrapperArgs = [ "--set" "JUPYTERLAB_DIR" "$out/share/jupyter/lab" ];
```

which only ever worked because a plain-attrs derivation flattens the list into one string that the setup hook re-splits through the shell. Python packages now build with `__structuredAttrs = true`, so `makeWrapperArgs` reaches the builder as a bash array whose elements are never expanded, and `makeWrapper` copies `$out` into the wrapper verbatim. The overlay swaps in `builtins.placeholder "out"`, which Nix rewrites to the real output path — no shell expansion involved, so it is correct under both attr styles

**Removal check:** build jupyterlab as nixpkgs has it, with no overlay in the way, and look for an unexpanded `$out` in the wrapper

```sh
grep -cF "JUPYTERLAB_DIR='\$out" \
  "$(nix build --no-link --print-out-paths --impure --expr \
    'let f = builtins.getFlake (toString ./.); in f.inputs.nixpkgs.legacyPackages.x86_64-linux.python3Packages.jupyterlab')/bin/jupyter-lab"
```

Prints `1` → keep the overlay. `0` → drop `overlay-jupyterlab` from `flake.nix` and from both host overlay lists

**Upstream:** [the offending `makeWrapperArgs`](https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/python-modules/jupyterlab/default.nix), [NixOS/nixpkgs#205690](https://github.com/NixOS/nixpkgs/issues/205690) (the `__structuredAttrs` tracking issue this class of breakage belongs to)

---

## `overlay-hyprland` — glaze pinned to 7.2.0

**Where:** `flake.nix` — and it must sit in the overlay list of **both** hosts, since both run Hyprland. It was on `nixos-pc` only for a while, which left `nixos-laptop` unbuildable

**Why:** nixpkgs carries `glaze` 8.0.0, which hyprland 0.56.1 does not build against, so the overlay pins hyprland's `glaze` **back** to 7.2.0 from GitHub. Note this is a downgrade — a newer nixpkgs `glaze` is therefore not by itself evidence the overlay can go. Without it the build fails like this, because hyprland's CMake falls back to fetching glaze over the network and the sandbox has no git:

```
-- glaze dependency not found, retrieving v7.2.0 with FetchContent
CMake Error: error: could not find git for clone of glaze
```

**Removal check:** build hyprland as nixpkgs has it, with no overlay in the way

```sh
nix build --no-link --impure --expr \
  'let f = builtins.getFlake (toString ./.); in f.inputs.nixpkgs.legacyPackages.x86_64-linux.hyprland'
```

Builds clean → drop `overlay-hyprland` from `flake.nix` and from both host overlay lists. Still fails on `glaze` → keep it, and bump the pinned tag only if hyprland itself moved on

---

## `bambu-studio.override { withNvidiaGLWorkaround = true; }`

**Where:** `home-manager/desktop/packages/packages.nix`, inside the `rokokol.packages.pc` group — the laptop has no NVIDIA GPU and takes the package as nixpkgs ships it. The `NVreg_EnableResizableBar=1` line in `nixos/pc/nvidia.nix` is downstream of this entry: it exists to make this route usable, see below

**Symptom it prevents:** on the proprietary NVIDIA GL driver the 3D viewport stays empty — the UI, the plater and the model list all render, the model does not. The option routes GL through Mesa's zink instead:

```
--set __GLX_VENDOR_LIBRARY_NAME mesa
--set MESA_LOADER_DRIVER_OVERRIDE zink
--set GALLIUM_DRIVER zink
```

**What it costs — and why the ReBAR line exists:** zink streams geometry through `ZINK_HEAP_DEVICE_LOCAL_VISIBLE` (index 3 of `enum zink_heap` in `zink_types.h`), the Vulkan memory type that is both `DEVICE_LOCAL` and `HOST_VISIBLE`. On NVIDIA that is BAR1, and with Resizable BAR off BAR1 is 256 MiB no matter how much VRAM the card has. A model past a few hundred thousand triangles exhausts it mid-render and the process dies:

```
MESA: error: zink: couldn't allocate memory: heap=3 size=2097152
MESA: error: ZINK: vkMapMemory failed (VK_ERROR_MEMORY_MAP_FAILED)
```

zink has a small-BAR mitigation (`zink_bo.c`: reclaim everything when that heap is `<= 256 MiB` on NVIDIA) and it is not enough. There is no env knob to steer allocations off that heap — `ZINK_DEBUG` has no heap flag. The only fix is to make BAR1 big, which is what `NVreg_EnableResizableBar=1` does; zink then sets `screen->resizable_bar` on its own, since it calls a BAR resizable once visible VRAM exceeds 90% of total VRAM

**Diagnostic trap:** the package is wrapped with `makeCWrapper --set`, which overwrites the environment rather than defaulting it. Every `__GLX_VENDOR_LIBRARY_NAME=nvidia` / `LIBGL_ALWAYS_SOFTWARE=1` / `MESA_LOADER_DRIVER_OVERRIDE=...` tried from a shell is silently discarded, so no shell experiment says anything about the GL path. `GDK_BACKEND=x11` does take, but it only moves the windowing backend and leaves zink in place — "tried X11, no change" is therefore not evidence

**Rejected alternatives**, all tested on driver 595.84 with the same build, wrapper env reconstructed minus the four zink vars (`glxinfo -B` under it reports `NVIDIA GeForce RTX 3060`, so the GL path is genuinely native and not a broken environment):

| route | result |
| --- | --- |
| native NVIDIA GL, Wayland | viewport empty, app otherwise healthy — it still slices |
| native GL + `GDK_BACKEND=x11` | viewport still empty |
| native GL + `GDK_BACKEND=x11` + GLX-built GLEW | segfault during startup |

The third is worth spelling out, since the reasoning behind it looks convincing and is wrong. Upstream never defines `GLEW_EGL` on Linux — `deps/GLEW/glew/CMakeLists.txt` guards it with `if(NOT CMAKE_SYSTEM_NAME STREQUAL "Linux")` under the comment `# we do not support wayland for now` — while nixpkgs `LD_PRELOAD`s its own `glew`, built `-DGLEW_EGL=ON` and linking `libEGL.so.1`. So the app does get a GLEW flavour upstream never builds against. Feeding it the matching GLX build (`glew` with `-DGLEW_EGL=OFF`, which drops `libEGL` from its `ldd`) does not fix the viewport — it crashes instead. The flavour mismatch is real and is not the cause

**Removal check:** the option only exists in nixpkgs for this bug, so its disappearance is the trigger

```sh
nix eval --raw .#nixosConfigurations.nixos-pc.pkgs.bambu-studio.meta.position \
  | cut -d: -f1 | xargs grep -c withNvidiaGLWorkaround
```

Non-zero → upstream still ships it, keep the override. Zero → the argument is gone, drop the override. To re-test before that happens, build the package as nixpkgs has it and load any model — the viewport either draws it or does not:

```sh
"$(nix build --no-link --print-out-paths .#nixosConfigurations.nixos-pc.pkgs.bambu-studio)"/bin/bambu-studio
```

**Upstream:** [NixOS/nixpkgs#498311](https://github.com/NixOS/nixpkgs/issues/498311) (the blank viewport, closed by the option this entry sets), [OrcaSlicer#11698](https://github.com/OrcaSlicer/OrcaSlicer/issues/11698) (the same zink BAR1 crash in the sibling slicer)

---

# Deferred

Not workarounds — gaps in this repo's own flake that nothing upstream forces. They sit here because the two extracted repos (`ddlc-sddm-theme`, `ddlc-palette`) already have both, so this list is what it takes to bring the parent up to the same footing. Same rule as above: each carries a mechanical check

## `ddlc-palette.follows` is set here, not in the repositories that read it

**Where:** `flake.nix` — every `ddlc-*` input carries `inputs.ddlc-palette.follows = "ddlc-palette";` next to the `nixpkgs` one

**What it costs:** nothing while the five lines are there, and a silent divergence the moment one is forgotten. Every `ddlc-*` repository declares the palette as an input of its own, so without a `follows` each pulls a copy: the lock held five, at four revisions (`ddlc-rofi-theme` on `6a2277a`, `ddlc-sddm-theme` on `68eedcf`, the two new ones on `7b7300d`, root on the current one). A colour corrected in the palette then reaches whichever theme was bumped and leaves the rest on the old hex — which is the one thing a single source of truth exists to prevent, and it is invisible except by reading the lock

**What it takes:** the `follows` belongs in the child repositories' own `flake.nix`, where each already makes `nixpkgs` follow. Once they do, these five lines are dead weight and can go — the palette is then one node because nothing asks for a second

**Check:**

```sh
python3 -c "import json;print([k for k in json.load(open('flake.lock'))['nodes'] if k.startswith('ddlc-palette')])"
```

Anything but `['ddlc-palette']` → a suffixed node is a second copy, and the `follows` for its parent is missing

## No `formatter` output

**Where:** `flake.nix` — the outputs attrset

**What it costs:** `nix fmt` does not work in this repo at all; the two hundred-odd `.nix` files are formatted by eye. Both extracted repos set `formatter = pkgs.nixfmt-tree` and run `nix fmt -- --ci` in CI, which does not rewrite anything and fails if a file is off-style

**What it takes:** add `formatter.${system} = pkgs.nixfmt-tree;`, then one treewide `nix fmt` commit on its own so the reformat never mixes with a real change

**Check:**

```sh
nix eval --raw .#formatter.x86_64-linux.name
```

Errors out → still missing

## `checks` is empty, so `nix flake check` proves nothing

**Where:** `flake.nix` — there is no `checks` output; `CLAUDE.md` already records this as "no `nix flake check` target wired up"

**What it costs:** validating the repo means remembering two separate `nix build .#nixosConfigurations.<host>...` invocations. `nix flake check` currently only confirms the outputs evaluate — it builds nothing

**What it takes:**

```nix
checks.${system} = {
  nixos-pc = self.nixosConfigurations.nixos-pc.config.system.build.toplevel;
  nixos-laptop = self.nixosConfigurations.nixos-laptop.config.system.build.toplevel;
};
```

Both hosts then build from one command, and `nix flake check` additionally validates every other output — module shape, `meta` on packages, app form

**Check:**

```sh
nix eval .#checks.x86_64-linux --apply builtins.attrNames
```

Errors out, or returns `[ ]` → still missing
