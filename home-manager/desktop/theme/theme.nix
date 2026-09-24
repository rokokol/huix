{ pkgs, ... }:

let
  gtkThemeName = "Gruvbox-Light";
  darkGtkThemeName = "Gruvbox-Dark";
  iconThemeName = "Mint-Y-Pink";
  colorScheme = "prefer-light";
  darkColorScheme = "prefer-dark";
  gruvbox = pkgs.callPackage ./gruvbox-gtk-theme.nix { };
in
{
  # toggle-theme.sh flips gtk-theme at runtime, so the theme name is not pinned
  # declaratively. Only the package is installed, and gruvbox-gtk-theme below ships both
  # variants
  gtk = {
    enable = true;

    iconTheme = {
      name = iconThemeName;
      package = pkgs.mint-y-icons;
    };

    # gtk-theme-name is written ONLY to settings.ini (via extraConfig), NOT to dconf
    # This is the baseline theme for apps that don't hook into the GtkSettings↔dconf bridge
    # A double tap counts only when the second finger lands within this many pixels of the
    # first; the stock 5 px is a mouse's precision, a finger lands within a couple of dozen
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 0;
      gtk-theme-name = gtkThemeName;
      gtk-double-click-distance = 24;
    };

    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 0;
      gtk-theme-name = gtkThemeName;
      gtk-double-click-distance = 24;
    };
  };

  home.packages = with pkgs; [
    # Removed from nixpkgs; vendored locally (see gruvbox-gtk-theme.nix)
    gruvbox
    gnome-themes-extra
    gsettings-desktop-schemas
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
    # libadwaita recolour sheets for toggle-theme.sh (need a fresh login to appear)
    GTK4_LIGHT_CSS = "${gruvbox}/share/themes/${gtkThemeName}/gtk-4.0/gtk-colors.css";
    GTK4_DARK_CSS = "${gruvbox}/share/themes/${darkGtkThemeName}/gtk-4.0/gtk-colors.css";
    THUNARX_DIRS = "/run/current-system/sw/lib/thunarx-3";
  };
}
