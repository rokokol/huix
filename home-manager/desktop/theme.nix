{ pkgs, config, ... }:

let
  gtkThemeName = "Gruvbox-Light";
  iconThemeName = "rose-pine-dawn";
  colorScheme = "prefer-light";
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
    THUNARX_DIRS = "/run/current-system/sw/lib/thunarx-3";
  };
}
