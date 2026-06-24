{ pkgs, ... }:

let
  gtkThemeName = "Gruvbox-Light";
  darkGtkThemeName = "Gruvbox-Dark";
  iconThemeName = "Mint-Y-Pink";
  colorScheme = "prefer-light";
  darkColorScheme = "prefer-dark";
in
{
  # gtk-theme переключает toggle_theme.sh в рантайме, поэтому имя темы декларативно
  # не фиксируем — только ставим пакет (gruvbox-gtk-theme ниже даёт обе вариации).
  gtk = {
    enable = true;

    iconTheme = {
      name = iconThemeName;
      package = pkgs.mint-y-icons;
    };

    # gtk-theme-name пишем ТОЛЬКО в settings.ini (через extraConfig), но НЕ в dconf.
    # Это базовая тема для приложений, которые не цепляются к dconf-мосту GtkSettings
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
    gruvbox-gtk-theme
    gnome-themes-extra
    gsettings-desktop-schemas
    gtk-engine-murrine
    gtk3
    libsForQt5.qt5.qtwayland
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
