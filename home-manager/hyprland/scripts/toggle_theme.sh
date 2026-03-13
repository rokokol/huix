#!/usr/bin/env bash

THEME=$(dconf read /org/gnome/desktop/interface/gtk-theme)
if [[ "${THEME,,}" == *"light"* ]]; then
  dconf write /org/gnome/desktop/interface/gtk-theme "'Gruvbox-Dark'"
  notify-send -u low "Dark theme set 🌑"
elif [[ "${THEME,,}" == *"dark"* ]]; then
  dconf write /org/gnome/desktop/interface/gtk-theme "'Gruvbox-Light'"
  notify-send -u low "Light theme set 🌕"
else
  notify-send -u critical "Cannot determine theme ヽ(ﾟДﾟ)ﾉ"
fi
