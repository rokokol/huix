---
title: Repository root
kind: module
dir: .
---

# Repository root

<!-- generated: module . -->

## [`checks.nix`](https://github.com/rokokol/huix/blob/master/checks.nix)

nix flake check already evaluates every host. The nixvim entries add the one thing
evaluation cannot say: whether the Lua nixvim assembles out of every module is
parseable — nixvim runs stylua over the generated init.lua, so a syntax error fails
the build. The station's VM test is not here; flake.nix says why
nix-lint holds every .nix file here to the standard the skill carries. It runs in a
build sandbox, so it leaves out the rules that need this flake's inputs; the eval
job runs the whole checker through apps.check-nix, where the inputs are there

**Units:** `sync`

## [`flake.nix`](https://github.com/rokokol/huix/blob/master/flake.nix)

Held at the commit before pi-coding-agent 1.5.0, whose recipe installs no pi-schema and so
breaks checks.pi-extensions; that commit already carries gpu-unlock (see WORKAROUNDS.md)

<!-- /generated -->
