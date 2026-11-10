---
title: Bump a flake input
kind: guide
---

# Bump a flake input

An input moves with one command, and the size of the change decides how much has to be checked afterwards

```sh
nix flake update             # every input
nix flake update nixpkgs     # one of them
```

## Before the switch

`nix flake check` evaluates every host and builds the Lua that nixvim assembles, so a broken module or a syntax error in the editor configuration fails here rather than at the next login

```sh
nix flake check
```

A change meant to leave behaviour alone is the one to measure. `nix run .#drv-diff` evaluates every host and every check here and at the commit before, and names the ones whose derivation path moved

```sh
nix run .#drv-diff
nix run .#drv-diff -- -r HEAD~3
```

An output that moves when nothing should have is either a bug just written or a dependency nobody knew about. Both are worth the minute

## The third-party flakes

An extracted flake must reuse the system `nixpkgs` and `home-manager` through `follows`, or it brings a copy of its own and the packages double. The `ddlc-*` inputs also follow `ddlc-palette`, since a second palette would drift from the first without a word

## When the lock is bumped

The lock is one file for every host, so two branches that both update it meet in a conflict. Take the newer lock whole rather than merging the two by hand, then run `nix flake check` again: a merged lock is a lock nobody has evaluated
