---
title: Add an agent skill
kind: guide
---

# Add an agent skill

For a standalone skill, add a `skill-` input. `home-manager/programs/agents/skills.nix` discovers those inputs and hands the selected skills to enabled agents. A skill that ships with a service uses that service's agent module instead

## The input

```nix
skill-thing = {
  url = "github:rokokol/thing-skill";
  flake = false;
};
```

The prefix makes the input discoverable, and its name without the prefix becomes the name the agent sees. This example uses a non-flake source. If the upstream is a flake, inspect its inputs and follow the repository's input policy

Run `nix flake lock` after the edit and verify the selected agent receives the skill. `nix flake check` does not prove the skill itself works

## Which homes get it

The module provides skills to a home when a supported agent is enabled. By default it selects all skill inputs, but a home can use an allow-list or exclusions:

```nix
rokokol.skills = {
  include = [ "contributing" "thing" ];   # null, the default, hands over everything
  exclude = [ "thing" ];                  # or drop one from the full set
};
```

These are alternative examples, not a configuration that includes and excludes the same skill. Both options are checked against existing inputs. The station agent has its own allow-list in `home-manager/home-mya-agent.nix`, so add the skill there if that agent needs it

## Where a skill keeps its state

A skill comes from the store and cannot be written. The owner's Pi configuration places `rokokol.agents.skillState` in the shared Pi directory, which synchronizes across hosts. Do not put a host-specific token there. A skill must be configured to use the intended state path; see `skills.nix` for examples and separate token paths
