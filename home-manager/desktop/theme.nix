{ pkgs, config, ... }:

let
  gtkThemeName = "Gruvbox-Light";
  darkGtkThemeName = "Gruvbox-Dark";
  iconThemeName = "rose-pine-dawn";
  colorScheme = "prefer-light";
  darkColorScheme = "prefer-dark";
in
{
  gtk = {
    enable = true;
    gtk4.theme = config.gtk.theme;

    theme = {
      name = gtkThemeName;
      package = pkgs.gruvbox-gtk-theme;
    };

    iconTheme = {
      name = iconThemeName;
      package = pkgs.rose-pine-icon-theme;
    };

    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 0;
    };

    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 0;
    };
  };

  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = colorScheme;
    gtk-theme = gtkThemeName;
    icon-theme = iconThemeName;
  };

  qt = {
    enable = true;
    platformTheme.name = "gtk3";
  };

  home.sessionVariables = {
    GTK_THEME_KEY = "/org/gnome/desktop/interface/gtk-theme";
    COLOR_SCHEME_KEY = "/org/gnome/desktop/interface/color-scheme";
    LIGHT_THEME = gtkThemeName;
    DARK_THEME = darkGtkThemeName;
    LIGHT_SCHEME = colorScheme;
    DARK_SCHEME = darkColorScheme;
    DEFAULT_THEME = gtkThemeName;
    DEFAULT_SCHEME = colorScheme;
    THUNARX_DIRS = "/run/current-system/sw/lib/thunarx-3";
  };
}
