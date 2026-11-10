---
title: home-manager/programs/creative
kind: module
dir: home-manager/programs/creative
---

# home-manager/programs/creative

<!-- generated: module home-manager/programs/creative -->

## [`home-manager/programs/creative/audacity.nix`](https://github.com/rokokol/huix/blob/master/home-manager/programs/creative/audacity.nix)

Audacity 4 has no script pipe module, so the MCP needs the stable Audacity 3 package

## [`home-manager/programs/creative/blender.nix`](https://github.com/rokokol/huix/blob/master/home-manager/programs/creative/blender.nix)

Enable the addon at launch without a binary preferences file or a change to user preferences

## [`home-manager/programs/creative/compress-video.nix`](https://github.com/rokokol/huix/blob/master/home-manager/programs/creative/compress-video.nix)

Upstream holds one skill among several in a single tree, so no skill-NAME input names it and the
directory is written out here. FFmpeg comes with the skill: the skill only picks its flags

## [`home-manager/programs/creative/default.nix`](https://github.com/rokokol/huix/blob/master/home-manager/programs/creative/default.nix)

## [`home-manager/programs/creative/freecad.nix`](https://github.com/rokokol/huix/blob/master/home-manager/programs/creative/freecad.nix)

FreeCAD with the addon of freecad-mcp, an XML-RPC server inside the running FreeCAD on
127.0.0.1:9875, a port both halves hard-code. The agents reach it through the freecad-mcp
bridge, which also runs scripts in a headless freecadcmd of the same FreeCAD

## [`home-manager/programs/creative/group.nix`](https://github.com/rokokol/huix/blob/master/home-manager/programs/creative/group.nix)

compress-video names its group here and not beside itself: a home can hold the skill without a
creative group, and skillGroups is typed over the groups that home declares

<!-- /generated -->
