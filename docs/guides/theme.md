---
title: Switch the light and dark theme
kind: guide
---

# Switch the light and dark theme

`SUPER+A` runs `scripts/toggle-theme.sh`, the choice is saved outside the store, and a rebuild never overwrites it. The rest of this page is what has to stay true for that to keep working

## Who owns the choice

The script owns it at runtime. It writes the GTK preference through dconf and remembers the side in `~/.local/state/huix/theme`, and the next login reads that file back. Declaring the same key in Nix would fight it: the Home Manager GTK module writes `gtk-theme` into dconf on every activation, so a rebuild would undo the toggle

That is why `theme.nix` holds no `color-scheme` and no `gtk-theme`. If a rebuild starts resetting the theme, look for a declared dconf key before anything else

## What follows the theme and what does not

- libadwaita applications ignore the GTK theme name and read `~/.config/gtk-4.0/gtk.css` instead, so the script points that file at the colour definitions of the chosen side. The full stylesheet is not used on purpose: it costs far more to parse and libadwaita keeps the colours alone
- The static `gtk-theme-name` in `gtk.gtk3` and `gtk.gtk4` writes `settings.ini` and deliberately stays where it is. It is the baseline before a login, not the choice
- The colours themselves come from the palette through the theme inputs. A hex written into a module is a reason to ask why it is not a role

## Moving the files

The paths the script writes to are session variables, `GTK4_LIGHT_CSS` and `GTK4_DARK_CSS`. A change there reaches the script only at the next login, because Home Manager writes the session file once per session
