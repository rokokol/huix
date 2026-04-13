{ pkgs, config, ... }:

{
  gtk = {
    enable = true;
    gtk4.theme = config.gtk.theme;

    theme = {
      name = "Gruvbox-Light";
      package = pkgs.gruvbox-gtk-theme;
    };

    iconTheme = {
      name = "rose-pine-dawn";
      package = pkgs.rose-pine-icon-theme;
    };

    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 0;
    };

    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 0;
    };
  };

  qt = {
    enable = true;
    platformTheme.name = "gtk3";
  };

  home.sessionVariables = {
    THUNARX_DIRS = "/run/current-system/sw/lib/thunarx-3";
  };
}
