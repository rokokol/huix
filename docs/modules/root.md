---
title: Корень репозитория
kind: module
---

# Корень репозитория

<!-- generated: module . -->

## `checks.nix`

nix flake check already evaluates every host. The nixvim entries add the one thing
evaluation cannot say: whether the Lua nixvim assembles out of every module is
parseable — nixvim runs stylua over the generated init.lua, so a syntax error fails
the build. The station's VM test is not here; flake.nix says why
nix-lint holds every .nix file here to the standard the skill carries. It runs in a
build sandbox, so it leaves out the rules that need this flake's inputs; the eval
job runs the whole checker through apps.check-nix, where the inputs are there

**Юниты:** `sync`

## `flake.nix`

Deliberately without nixpkgs.follows: nixvim pins its own nixpkgs and warns if you override it

<!-- /generated -->
