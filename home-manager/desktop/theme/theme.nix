{ pkgs, ... }:

let
  gtkThemeName = "Gruvbox-Light";
  darkGtkThemeName = "Gruvbox-Dark";
  iconThemeName = "Mint-Y-Pink";
  colorScheme = "prefer-light";
  darkColorScheme = "prefer-dark";
in
{
  # ВНИМАНИЕ: НЕ задавать здесь gtk.theme — модуль gtk дописывает имя темы в dconf
  # (org/gnome/desktop/interface/gtk-theme), и тогда каждый nixos-rebuild на
  # `dconf load` затирает рантайм-выбор светлым дефолтом (тема «слетает» на светлую).
  # gtk-theme переключает toggle_theme.sh в рантайме, поэтому имя темы декларативно
  # не фиксируем — только ставим пакет (gruvbox-gtk-theme ниже даёт обе вариации).
  gtk = {
    enable = true;

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
    gruvbox-gtk-theme
    gnome-themes-extra
    gsettings-desktop-schemas
    gtk-engine-murrine
    gtk3
    libsForQt5.qt5.qtwayland
    qt6.qtwayland
  ];

  # icon-theme не переключается — держим декларативно. color-scheme и gtk-theme
  # сюда НЕ кладём: ими владеет toggle_theme.sh (рантайм + state-файл), иначе их
  # затирает `dconf load` на каждом ребилде (см. комментарий к gtk выше).
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
