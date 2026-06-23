{ pkgs, config, ... }:

let
  gtkThemeName = "Gruvbox-Light";
  darkGtkThemeName = "Gruvbox-Dark";
  iconThemeName = "Mint-Y-Pink";
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
      package = pkgs.mint-y-icons;
    };

    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 0;
    };

    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 0;
    };
  };

  home.packages = with pkgs; [
    gnome-themes-extra
    gsettings-desktop-schemas
    gtk-engine-murrine
    gtk3
    libsForQt5.qt5.qtwayland
    qt6.qtwayland
  ];

  # icon-theme не переключается — его держим декларативно. А вот color-scheme и
  # gtk-theme переключает toggle_theme.sh в рантайме; если задать их здесь, каждый
  # nixos-rebuild будет `dconf load`-ом затирать выбор светлым дефолтом (тема
  # «слетает» на светлую). Поэтому этими двумя ключами владеет рантайм-тоггл +
  # его state-файл, а не декларация.
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
