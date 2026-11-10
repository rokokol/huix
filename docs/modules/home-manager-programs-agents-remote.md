---
title: home-manager/programs/agents/remote
kind: module
dir: home-manager/programs/agents/remote
---

# home-manager/programs/agents/remote

<!-- generated: module home-manager/programs/agents/remote -->

## [`home-manager/programs/agents/remote/dav-mcp.nix`](https://github.com/rokokol/huix/blob/master/home-manager/programs/agents/remote/dav-mcp.nix)

The calendar MCP server for the user whose Radicale login the host keeps, which
nixos/services/tools/dav-mcp.nix declares, and the skill that says which calendar is whose

## [`home-manager/programs/agents/remote/default.nix`](https://github.com/rokokol/huix/blob/master/home-manager/programs/agents/remote/default.nix)

## [`home-manager/programs/agents/remote/group.nix`](https://github.com/rokokol/huix/blob/master/home-manager/programs/agents/remote/group.nix)

## [`home-manager/programs/agents/remote/mail-skill.nix`](https://github.com/rokokol/huix/blob/master/home-manager/programs/agents/remote/mail-skill.nix)

The seam to rokokol/mail-skill's skill: the system's module ships it at the revision of the
service, and this hands it to the agents of the one user the socket belongs to. A host with
no service, or a user the socket refuses, gets no skill that could only fail

## [`home-manager/programs/agents/remote/print-skill.nix`](https://github.com/rokokol/huix/blob/master/home-manager/programs/agents/remote/print-skill.nix)

## [`home-manager/programs/agents/remote/telegram-skill.nix`](https://github.com/rokokol/huix/blob/master/home-manager/programs/agents/remote/telegram-skill.nix)

The seam to rokokol/telegram-skill's skill: the system's module ships it at the revision of
the service, and this hands it to the agents of the one user the socket belongs to. A host
with no service, or a user the socket refuses, gets no skill that could only fail

<!-- /generated -->
