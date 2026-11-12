<div align="center">

<img src="../assets/laptop-wallpaper.png" alt="the laptop wallpaper" width="380"/>

<em>everything that makes the desktop good lives here</em>

</div>

# The Home Manager layer

[![huix](https://img.shields.io/badge/huix-up-222222?style=for-the-badge&logo=nixos&logoColor=white)](../README.md)
[![hyprland](https://img.shields.io/badge/hyprland-desktop-00AAAE?style=for-the-badge&logo=hyprland&logoColor=white)](desktop/hyprland/README.md)
[![programs](https://img.shields.io/badge/programs-programs-7E57C2?style=for-the-badge)](programs/README.md)
[![nixvim](https://img.shields.io/badge/nixvim-neovim-019733?style=for-the-badge&logo=neovim&logoColor=white)](programs/nixvim/README.md)

Everything used every day is assembled here: the applications, the shell, the look and the desktop itself. The hardware and the system services are in the [NixOS layer](../nixos/README.md)

The PC and the laptop get a full graphical desktop, and the server gets the tools a terminal needs. The applications have their own [section](programs/README.md)

## Which home and which host

A host has one entry file here, and the flake hands it to that host's Home Manager. The station carries more than one home: the owner's, the one of the agent that answers in Telegram, and the guests that session logs in to. They are separate values of the same flake, so a change to a shared module reaches every one of them

One flag decides whether the desktop reaches a host at all, and the modules of [Hyprland](desktop/hyprland/README.md) and the rest of the desktop follow it. That is why the same configuration gives a workstation its desktop and leaves the server without one

Have a look at [Hyprland](desktop/hyprland/README.md) and [Nixvim](programs/nixvim/README.md) to see the desktop and the editor
