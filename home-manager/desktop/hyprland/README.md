# Hyprland

[![huix](https://img.shields.io/badge/huix-up-222222?style=for-the-badge&logo=nixos&logoColor=white)](../../../README.md)
[![home-manager](https://img.shields.io/badge/home--manager-user_layer-5E81AC?style=for-the-badge)](../../README.md)
[![scripts](https://img.shields.io/badge/scripts-scripts-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)](../../../scripts/README.md)
[![screen-shader](https://img.shields.io/badge/screen--shader-effects-FF4088?style=for-the-badge&logo=opengl&logoColor=white)](https://github.com/rokokol/hyprland-screen-shader)
[![rofi-wooordhunt](https://img.shields.io/badge/rofi--wooordhunt-dictionary-F4A100?style=for-the-badge)](https://github.com/rokokol/rofi-wooordhunt)

Hyprland is the desktop of the PC and the laptop: the windows, the workspaces and the monitors behave the way I like them. A launcher, the clipboard history, the notifications, screenshots with text recognition, a dictionary and the screen effects are all at hand

Some of it answers the keyboard, and some sits behind the launcher and the bar. The bar is in [its own section](services/waybar/README.md), and the automation is in [the scripts](../../../scripts/README.md)

## The convertible laptop

The laptop folds into a tablet: the screen turns by itself, the touch gestures page through the workspaces, and the interface becomes comfortable for fingers and for a pen

## Scaling the screen to taste

The screen zooms from three devices, and the three feel the same while none of them can replace another:

- A physical mouse wheel answers `ALT+SUPER+wheel` through `scripts/zoom.sh`
- A touchpad pinch zooms through a Hyprland gesture, because a wheel bind never fires for a touchpad
- A three-finger pinch on the touchscreen zooms through hyprgrass

A new way of zooming joins these rather than replacing one, and the touchpad and the touchscreen keep their own because the gesture engine runs no command of its own

## The power key and the lid

The power key opens a menu, and the lid keeps the laptop awake while the dock is in use. Both work by handing the event over instead of acting on it: the key reaches Hyprland, and the lid meets a lock that only the session takes

Outside the graphical session the kernel keeps its own behaviour, so the lid still suspends a laptop taken to a text console

## Notifications

Notifications arrive through mako, in the colours of the current theme, and a notification that carries no urgency hint is coloured like every other rather than left in the default blue. The feed, the do-not-disturb switch and the history live behind the launcher

## Components

- [Screen effects and software brightness](https://github.com/rokokol/hyprland-screen-shader)
- [Dictionary](https://github.com/rokokol/rofi-wooordhunt)
- [Lock screen](https://github.com/rokokol/ddlc-hyprlock)
