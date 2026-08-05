{ pkgs, ... }:

let
  gtkThemeName = "Gruvbox-Light";
  darkGtkThemeName = "Gruvbox-Dark";
  iconThemeName = "Mint-Y-Pink";
  colorScheme = "prefer-light";
  darkColorScheme = "prefer-dark";
in
{
  # gtk-theme is toggled by toggle-theme.sh at runtime, so we don't pin the theme
  # name declaratively — we only install the package (gruvbox-gtk-theme below ships both variants)
  gtk = {
    enable = true;

    iconTheme = {
      name = iconThemeName;
      package = pkgs.mint-y-icons;
    };

    # We write gtk-theme-name ONLY to settings.ini (via extraConfig), NOT to dconf.
    # This is the baseline theme for apps that don't hook into the GtkSettings↔dconf bridge
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 0;
      gtk-theme-name = gtkThemeName;
    };

    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 0;
      gtk-theme-name = gtkThemeName;
    };
  };

  home.packages = with pkgs; [
    gnome-themes-extra
    gsettings-desktop-schemas
    gtk-engine-murrine
    gtk3
    qt5.qtwayland
    qt6.qtwayland
  ];

  dconf.settings."org/gnome/desktop/interface" = {
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
    THUNARX_DIRS = "/run/current-system/sw/lib/thunarx-3";
  };
}
