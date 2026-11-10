---
title: home-manager/desktop/hyprland/services
kind: module
dir: home-manager/desktop/hyprland/services
---

# home-manager/desktop/hyprland/services

<!-- generated: module home-manager/desktop/hyprland/services -->

## [`home-manager/desktop/hyprland/services/hypridle.nix`](https://github.com/rokokol/huix/blob/master/home-manager/desktop/hyprland/services/hypridle.nix)

## [`home-manager/desktop/hyprland/services/hyprland-packages.nix`](https://github.com/rokokol/huix/blob/master/home-manager/desktop/hyprland/services/hyprland-packages.nix)

## [`home-manager/desktop/hyprland/services/hyprlock.nix`](https://github.com/rokokol/huix/blob/master/home-manager/desktop/hyprland/services/hyprlock.nix)

The lock screen and Monika's dialog live in rokokol/ddlc-hyprlock, and its default font is
Doki with Nunito Black behind it; the seam is the shader it flashes the screen with. The
dialog is on by default — the
laptop opts out in home-laptop.nix — and hypridle.nix reads ddlc.hyprlock.lockCommand
screenShader already implies flash = "screen-shader", so setting flash here would only
undo it. The layout is one attrset in the module, which also computes the engine's wrap
width from it — nudging it through programs.hyprlock.settings splits that in two

## [`home-manager/desktop/hyprland/services/lid-mode.nix`](https://github.com/rokokol/huix/blob/master/home-manager/desktop/hyprland/services/lid-mode.nix)

## [`home-manager/desktop/hyprland/services/mako.nix`](https://github.com/rokokol/huix/blob/master/home-manager/desktop/hyprland/services/mako.nix)

Senders decide their own expire timeout otherwise, and web pushes asking to stay until
clicked (Firefox requireInteraction) then hang forever — the sections below decide instead

## [`home-manager/desktop/hyprland/services/rofi-wooordhunt.nix`](https://github.com/rokokol/huix/blob/master/home-manager/desktop/hyprland/services/rofi-wooordhunt.nix)

The dictionary lives in rokokol/rofi-wooordhunt. Its mode names itself over rofi's script
protocol, so the emoji belongs here and not in programs/rofi.nix with the display-* lines

## [`home-manager/desktop/hyprland/services/screen-shader.nix`](https://github.com/rokokol/huix/blob/master/home-manager/desktop/hyprland/services/screen-shader.nix)

The manager itself lives in github:rokokol/hyprland-screen-shader. Enabling it brings
the keys, the picker and its rofi modi along — huix only says when, and waybar/shader.nix
adds the indicator
The module emits its own restore call on the start and reload events (the shader slot
is lost on every reload) — don't add that handler to hyprland.lua as well

## [`home-manager/desktop/hyprland/services/tablet-mode.nix`](https://github.com/rokokol/huix/blob/master/home-manager/desktop/hyprland/services/tablet-mode.nix)

The mode itself is two user units and the switch binds; what happens on the way in and
out is tablet-mode.sh, which is also what the waybar virt-keyboard button calls

## [`home-manager/desktop/hyprland/services/titlebars.nix`](https://github.com/rokokol/huix/blob/master/home-manager/desktop/hyprland/services/titlebars.nix)

The bars are for a finger: off in the config, and tablet-mode.sh turns the enabled keyword
on when the laptop is folded. Every window gets one, its own close button or not, so a
finger finds the same buttons in the same place everywhere

## [`home-manager/desktop/hyprland/services/touch-gestures.nix`](https://github.com/rokokol/huix/blob/master/home-manager/desktop/hyprland/services/touch-gestures.nix)

Hyprland itself gives a touchscreen taps and drags only; the gestures are the plugin's.
The plugin also warps the pointer to every touch, so the magnifier anchors under the
fingers. Scrolling is not emulated: applications with wl_touch scroll with one finger by
themselves, and a wheel sent under the fingers only fought them. A right click is not
among the gestures either, and the applications answer a long press with their own
context menu
The switch that turns the device off by hand belongs here too, since this module owns the
touchscreen: nothing touches the panel and it reports contacts with no coordinates all the
same, and Hyprland warps the pointer to each of them (scripts/touchscreen.sh says the rest)

## [`home-manager/desktop/hyprland/services/wallpaper-collager.nix`](https://github.com/rokokol/huix/blob/master/home-manager/desktop/hyprland/services/wallpaper-collager.nix)

## [`home-manager/desktop/hyprland/services/wl-clip-persist.nix`](https://github.com/rokokol/huix/blob/master/home-manager/desktop/hyprland/services/wl-clip-persist.nix)

Persistent Wayland clipboard daemon. A user-session service, so it lives in HM
alongside the other graphical-session units (mako, hypridle, swayosd) rather
than in nixos/. wl-clipboard (wl-copy/wl-paste) comes from other HM modules

**Юниты:** `wl-clip-persist`

<!-- /generated -->
