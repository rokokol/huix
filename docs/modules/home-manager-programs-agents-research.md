---
title: Модули home-manager/programs/agents/research
kind: module
---

# Модули home-manager/programs/agents/research

<!-- generated: module home-manager/programs/agents/research -->

## `home-manager/programs/agents/research/default.nix`

## `home-manager/programs/agents/research/docs-mcp.nix`

MCP servers that answer from documentation rather than from the user's own data: mcp-nixos,
over the NixOS, Home Manager and nixpkgs indexes of a channel rather than this flake's pin, and
DeepWiki, which answers about a public GitHub repository from an index Cognition hosts

## `home-manager/programs/agents/research/geo-sleuth.nix`

## `home-manager/programs/agents/research/group.nix`

## `home-manager/programs/agents/research/kinship-research.nix`

## `home-manager/programs/agents/research/papers.nix`

The seam to rokokol/papers-skill: the module owns the paper-search-mcp package, both
binaries on PATH, the PAPER_SEARCH_MCP_ENV_FILE variable, the MCP server, the skill's
directory, the PaperQA2 environment and its pqa settings preset. This seam hands the skill to
the agents beside the server. What the module ships none of is the env file with the keys, which
nixos/services/tools/paper-search.nix renders from sops, and the corpus folder, which is
the cache the skill downloads into. The Ollama models the preset names are pulled by hand

<!-- /generated -->
