<div align="center">

<img src="./assets/logo.jpg" alt="huix" width="200"/>

# huix

**My NixOS flake: a desktop with NVIDIA and CUDA, a laptop on Hyprland and a home server without a screen** （´ω｀♡%）

![NixOS](https://img.shields.io/badge/NixOS-system-5277C3?style=flat&logo=nixos&logoColor=white)
![Nix](https://img.shields.io/badge/Nix-flakes-7EBAE4?style=flat&logo=nixos&logoColor=white)
![Hyprland](https://img.shields.io/badge/WM-Hyprland-00AAAE?style=flat&logo=hyprland&logoColor=white)
[![assets](https://img.shields.io/badge/assets-third--party-FF80C0?style=flat)](ASSETS.md)
[![workarounds](https://img.shields.io/badge/docs-workarounds-555?style=flat)](WORKAROUNDS.md)
[![deviations](https://img.shields.io/badge/docs-deviations-555?style=flat)](DEVIATIONS.md)
[![pitfalls](https://img.shields.io/badge/docs-pitfalls-555?style=flat)](PITFALLS.md)
[![license](https://img.shields.io/badge/license-MIT-3DA639?style=flat)](LICENSE)
[![eval](https://github.com/rokokol/huix/actions/workflows/eval.yml/badge.svg)](https://github.com/rokokol/huix/actions/workflows/eval.yml)
[![Ask DeepWiki](./assets/ask-deepwiki.svg)](https://deepwiki.com/rokokol/huix)

<a href="https://github.com/rokokol/huix"><img src="https://count.owenewans.org/rokokol/huix?theme=original-new&notitle" alt="Stars, pull requests, issues and commits of the huix repository" width="800"/></a>

</div>

In short, this is my NixOS for a work PC, a laptop and a home server: Hyprland, nixvim and a pile of everyday applications. Some programs I keep outside the configuration, and for everything else I try to build a comfortable environment of my own

## Commands

```sh
sudo nixos-rebuild switch --flake .#nixos-pc   # or .#nixos-laptop
rebuild                                        # the same alias for the current host
rebuilds                                       # the same, but packages from the Yandex mirror, when the network misbehaves
```

The station keeps no checkout of its own: the PC builds it and ships it over Tailscale SSH

```sh
nixos-rebuild switch --flake .#nixos-station --target-host rokokol@nixos-station --sudo --ask-sudo-password
nix build .#station-boot-test -L      # the station in virtual machines beside a router and the PC, only on request
nix build .#station-install-test -L   # its installer image in virtual machines: the refusals, then a full install
```

The station installs from a flash drive. The [installation guide](docs/guides/install-station.md) explains the image and its secrets. What the station can do is in [the system layer](nixos/README.md#the-station)

If the hardware changed, inspect the output of `sudo nixos-generate-config --show-hardware-config` on that host before you update its hardware configuration. Preserve the existing file until you have reviewed the changes

MATLAB runs through Nix too (★^O^★):

```sh
nix run gitlab:doronbehar/nix-matlab#matlab-shell
nix shell gitlab:doronbehar/nix-matlab#matlab --command /run/media/rokokol/MATHWORKS_R2025A/install
```

## Hosts

| Host | Purpose |
| ---- | ------- |
| Work PC | A work host for development and creative tasks |
| Convertible laptop | A work host with a touchscreen, a pen and a tablet mode |
| Home server | Keeps the backups, assembles the state of the hosts and serves the household services |

## Repository map

The configuration is split into layers, and each layer has its own README:

[![nixos](https://img.shields.io/badge/nixos-system_layer-5277C3?style=for-the-badge&logo=nixos&logoColor=white)](nixos/README.md)
[![services](https://img.shields.io/badge/services-services-0E7C7B?style=for-the-badge)](nixos/services/README.md)
[![fonts](https://img.shields.io/badge/fonts-fonts-EA4AAA?style=for-the-badge&logo=googlefonts&logoColor=white)](nixos/fonts/README.md)
[![home-manager](https://img.shields.io/badge/home--manager-user_layer-5E81AC?style=for-the-badge)](home-manager/README.md)
[![hyprland](https://img.shields.io/badge/hyprland-desktop-00AAAE?style=for-the-badge&logo=hyprland&logoColor=white)](home-manager/desktop/hyprland/README.md)
[![programs](https://img.shields.io/badge/programs-programs-7E57C2?style=for-the-badge)](home-manager/programs/README.md)
[![nixvim](https://img.shields.io/badge/nixvim-neovim-019733?style=for-the-badge&logo=neovim&logoColor=white)](home-manager/programs/nixvim/README.md)
[![scripts](https://img.shields.io/badge/scripts-scripts-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)](scripts/README.md)

## Extracted into their own repositories

The pieces that outgrew the configuration live in flakes of their own: huix takes them as inputs and keeps one seam for each. The whole family, the configuration itself included, carries the [huix](https://github.com/topics/huix) topic

[![screen-shader](https://img.shields.io/badge/screen--shader-effects-FF4088?style=for-the-badge&logo=opengl&logoColor=white)](https://github.com/rokokol/hyprland-screen-shader)
[![rofi-wooordhunt](https://img.shields.io/badge/rofi--wooordhunt-dictionary-F4A100?style=for-the-badge)](https://github.com/rokokol/rofi-wooordhunt)
[![virtual-media-devices](https://img.shields.io/badge/virtual--media--devices-camera_and_microphone-2E9E9E?style=for-the-badge&logo=ffmpeg&logoColor=white)](https://github.com/rokokol/virtual-media-devices)
[![skvpn](https://img.shields.io/badge/skvpn-VPN_client-2B5797?style=for-the-badge&logo=python&logoColor=white)](https://github.com/rokokol/skvpn)
[![archive-mount](https://img.shields.io/badge/archive--mount-archives_as_folders-D1897E?style=for-the-badge)](https://github.com/rokokol/archive-mount.yazi)
[![rename-case](https://img.shields.io/badge/rename--case-case_and_transliteration-DD77BB?style=for-the-badge)](https://github.com/rokokol/rename-case.yazi)
[![ddlc-palette](https://img.shields.io/badge/ddlc--palette-colours-BB5599?style=for-the-badge)](https://github.com/rokokol/ddlc-palette)
[![ddlc-sddm-theme](https://img.shields.io/badge/ddlc--sddm--theme-login_screen-FF80C0?style=for-the-badge&logo=qt&logoColor=white)](https://github.com/rokokol/ddlc-sddm-theme)
[![ddlc-hyprlock](https://img.shields.io/badge/ddlc--hyprlock-lock_screen-58E1FF?style=for-the-badge)](https://github.com/rokokol/ddlc-hyprlock)
[![ddlc-rofi-theme](https://img.shields.io/badge/ddlc--rofi--theme-rofi_theme-EE2A7B?style=for-the-badge)](https://github.com/rokokol/ddlc-rofi-theme)
[![ddlc.nvim](https://img.shields.io/badge/ddlc.nvim-editor_theme-76C332?style=for-the-badge&logo=neovim&logoColor=white)](https://github.com/rokokol/ddlc.nvim)
[![ddlc-themes](https://img.shields.io/badge/ddlc--themes-kitty_and_btop-72D0FA?style=for-the-badge)](https://github.com/rokokol/ddlc-themes)

## A few notes

- The light and the dark theme switch on the fly, and the choice survives reboots and rebuilds
- What runs on the machines is in [the system layer](nixos/README.md) and in the [services](nixos/services/README.md) section

<br/>

---

<div align="center">

<img src="./assets/felix.png" alt="Felix Argail" width="480"/>

<em>an average nixos user :3</em>

<br/>

<table>
<tr><td align="center">

❄️❄️🚀 <b>ALL YOUR PACKAGE MANAGERS ARE SHIT</b> 🤬❄️<br/> MUTABLE GARBAGE 🌋🚀❄️ YOU HAVE TO SWITCH ❄️ TO NIX ❄️❤️<br/> 😍 SWITCH TO NIX ❄️❄️<br/> SWITCH TO NIX, DAMN IT 😡❄️<br/> 🚀 I NEED ❄️❄️ DECLARATIVENESS, DAMN IT 🚀❄️<br/> THE DECLARATIVE NIX APPROACH 😍❤️🚀❄️<br/> ALL YOUR OSES ARE IMPERATIVE 🤬💩 GARBAGE ❄️<br/> ❄️ SWITCH TO NIX

</td></tr>
</table>

<a href="https://никспобеда.рф"><img src="https://img.shields.io/badge/никспобеда.рф-❄️_NIX_VICTORY-1793D1?style=for-the-badge&logo=nixos&logoColor=white" alt="никспобеда.рф"/></a>

<sub>❄️ made with declarative love · NixOS ❄️</sub>

</div>
