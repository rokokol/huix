---
title: lib/docs
kind: module
dir: lib/docs
---

# lib/docs

<!-- generated: module lib/docs -->

## [`lib/docs/build.nix`](https://github.com/rokokol/huix/blob/master/lib/docs/build.nix)

The documentation corpus and what is built from it: the site a reader opens and the server an
agent asks. The facts come from the flake evaluation rather than from a command run at build
time, so the sandbox renders a corpus that cannot disagree with the configuration it describes

## [`lib/docs/facts.nix`](https://github.com/rokokol/huix/blob/master/lib/docs/facts.nix)

Facts the documentation generator renders into pages. Everything here is computed while the
flake evaluates, so the renderer never runs `nix eval`: a build sandbox has no daemon, and a
corpus built outside one could disagree with the configuration it claims to describe

<!-- /generated -->
