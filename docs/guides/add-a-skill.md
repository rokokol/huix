---
title: Add an agent skill
kind: guide
---

# Add an agent skill

A skill is a flake input and nothing else. No list names it, because `home-manager/programs/agents/skills.nix` hands every input whose name starts with `skill-` to the agents of each home that runs one

## The input

```nix
skill-thing = {
  url = "github:rokokol/thing-skill";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Two things about that block carry the whole job: the prefix `skill-` makes the input a skill, and its name without the prefix becomes the name the agent sees. A third-party flake must follow the system `nixpkgs`, or it drags in a copy of its own

Run `nix flake lock` after the edit. If the skill ships a flake of its own, `nix flake check` proves it evaluates

## Which homes get it

Every home that imports the module gets every skill input, so a skill that only one host should have is taken out by name:

```nix
rokokol.skills = {
  include = [ "contributing" "thing" ];   # null, the default, hands over everything
  exclude = [ "thing" ];                  # or drop one from the full set
};
```

Both options live in the module and are checked against the inputs that exist, so a name that is not an input fails the evaluation instead of doing nothing

## Where a skill keeps its state

A skill comes from the store and cannot be written. The notes, the drafts and the standing permissions it keeps go to `rokokol.agents.skillState`, which each host has for itself: a token belongs to one machine, since every application issues its own
