#!/usr/bin/env bash

THEME=$(dconf read /org/gnome/desktop/interface/gtk-theme)
if [[ "${THEME,,}" == *"light"* ]]; then
  dconf write /org/gnome/desktop/interface/gtk-theme "'Gruvbox-Dark'"
elif [[ "${THEME,,}" == *"dark"* ]]; then
  dconf write /org/gnome/desktop/interface/gtk-theme "'Gruvbox-Light'"
fi
