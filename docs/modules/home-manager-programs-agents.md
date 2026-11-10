---
title: home-manager/programs/agents
kind: module
dir: home-manager/programs/agents
---

# home-manager/programs/agents

<!-- generated: module home-manager/programs/agents -->

## [`home-manager/programs/agents/agents.nix`](https://github.com/rokokol/huix/blob/master/home-manager/programs/agents/agents.nix)

Shared registries let each agent use tools without an import of another agent's module

## [`home-manager/programs/agents/default.nix`](https://github.com/rokokol/huix/blob/master/home-manager/programs/agents/default.nix)

## [`home-manager/programs/agents/huix-docs.nix`](https://github.com/rokokol/huix/blob/master/home-manager/programs/agents/huix-docs.nix)

The documentation of this configuration, answered from the checkout rather than from the store:
an agent that asks about the tree it is editing gets the tree it is editing, and a page rendered
a minute ago is already in the answer. See `lib/docs/build.nix` for the rendered copy

## [`home-manager/programs/agents/skills.nix`](https://github.com/rokokol/huix/blob/master/home-manager/programs/agents/skills.nix)

The skills of the flake's skill-NAME inputs, each handed to the agents as NAME, for every home
that imports this module and runs an agent. A skill comes from the store and cannot be
written, so the notes and drafts a skill keeps go to `rokokol.agents.skillState`. A token stays
on its host: each app issues its own

<!-- /generated -->
