---
title: Switch the light and dark theme
kind: guide
---

# Switch the light and dark theme

`SUPER+A` runs `scripts/toggle-theme.sh` and saves the choice outside the store. Hyprland runs the script with `--sync` when its configuration loads, so it can restore the saved choice

## Who owns the choice

The script owns it at runtime. It writes the GTK preference through dconf and remembers the choice in `${XDG_STATE_HOME:-$HOME/.local/state}/huix/theme`. Hyprland calls `--sync` on startup and reload to restore it

`home-manager/desktop/theme/theme.nix` does not declare `color-scheme` or `gtk-theme` in dconf. It also does not set `gtk.theme`, which would make Home Manager write the GTK theme to dconf. Declaring either runtime choice there would compete with the toggle

## What follows the theme and what does not

- libadwaita applications ignore the GTK theme name and read `~/.config/gtk-4.0/gtk.css` instead, so the script points that file at the colour definitions of the chosen side. The full stylesheet is not used on purpose: it costs far more to parse and libadwaita keeps the colours alone
- The static `gtk-theme-name` in `gtk.gtk3` and `gtk.gtk4` writes `settings.ini` and deliberately stays where it is. It is the baseline before a login, not the choice
- The colours themselves come from the palette through the theme inputs. A hex written into a module is a reason to ask why it is not a role

## Moving the files

`GTK4_LIGHT_CSS` and `GTK4_DARK_CSS` name the source files for the GTK CSS symlink. Changes to these session variables reach an existing session only after a fresh login. The script also requires its theme and dconf variables; see its environment guard before changing the wrapper
