---
title: Bump a flake input
kind: guide
---

# Bump a flake input

An input moves with one command, and the size of the change decides how much has to be checked afterwards

```sh
nix flake update             # every input
nix flake update nixpkgs-stable  # one input
```

An input pinned to a commit in its URL does not advance until that URL changes. Check `flake.nix` and its pin rationale before you update `nixpkgs`

## Before the switch

`nix flake check` evaluates every host and builds the Lua that nixvim assembles, so a broken module or a syntax error in the editor configuration fails here rather than at the next login

```sh
nix flake check
```

A change meant to leave behaviour alone is the one to measure. `nix run .#drv-diff` evaluates the outputs here and at `HEAD` by default, and names the derivation paths that moved

```sh
nix run .#drv-diff
nix run .#drv-diff -- -r HEAD~3
```

An output that moves when nothing should have is either a bug just written or a dependency nobody knew about. The command exits nonzero when it finds a change; review the output rather than treating that status alone as a failure

## The third-party flakes

Extracted flakes generally follow the system `nixpkgs` and `home-manager` to avoid separate inputs. Check the comments in `flake.nix` before changing an existing input: some deliberately use a different package set. The `ddlc-*` inputs also follow `ddlc-palette`

## When the lock is bumped

The lock is shared by every host. When branches conflict, retain the intended input changes from both sides and regenerate the lock if necessary. Inspect the resulting diff and run the checks again; choosing the newer file alone can discard an input added on the other branch

If generated documentation is stale after the update, run `nix run .#docs-build` and review its changes. A green `nix flake check` does not build every host closure or exercise every application at runtime
