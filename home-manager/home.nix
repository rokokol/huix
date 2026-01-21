{ config, pkgs, lib, ... }:

{
  home.username = "rokokol";
  home.homeDirectory = "/home/rokokol";
  home.stateVersion = "25.11";

  home.packages = with pkgs; [
#    lolcat  
  ];

  # Алиасы для терминала
  home.shellAliases = {
    ll = "ls -l";
    la = "ls -la";
    rebuild = "sudo nixos-rebuild switch --flake ~/huix";
  };

  programs.git = {
    enable = true;
    settings.user.Name  = "rokokol";              
    settings.user.Email = "mailofilyusha@gmail.com"; 
  };

  programs.gh.enable = true;

  home.sessionVariables = {
    QT_QPA_PLATFORM = "wayland";
    SDL_VIDEODRIVER = "wayland";
    XDG_CURRENT_DESKTOP = "GNOME";
  };

  dconf.settings = {
    # 1. ТЕМА И ИНТЕРФЕЙС
    "org/gnome/desktop/interface" = {
      color-scheme = "default"; 
      icon-theme = "Papirus";
    };
    
    "org/gnome/desktop/search-providers" = {
      # Отключает поиск через Epiphany (стандартный "Веб")
      disabled = [ "org.gnome.Epiphany.desktop" ];
    };

    # 2. ЗАКРЕПЛЕННЫЕ ПРИЛОЖЕНИЯ И РАСШИРЕНИЯ
    "org/gnome/shell" = {
      favorite-apps = [
        "firefox.desktop"
        "org.gnome.Nautilus.desktop"
        "org.gnome.Console.desktop"
        "obsidian.desktop"
      ];
      disable-user-extensions = false;
      
      # ИСПРАВЛЕНИЕ 1: Убрал Pano, добавил GPaste
      enabled-extensions = [
	"GPaste@gnome-shell-extensions.gnome.org"
	"Vitals@CoreCoding.com"
      ];
    };

    # 3. НАСТРОЙКИ ПОВЕДЕНИЯ ОКОН
    "org/gnome/shell/window-switcher" = {
      current-workspace-only = true;
    };
    
    "org/gnome/desktop/wm/keybindings" = {
      switch-applications = [];
      switch-applications-backward = [];
      switch-windows = ["<Alt>Tab"];
      switch-windows-backward = ["<Shift><Alt>Tab"];
    };
    
    # 5. СИСТЕМНЫЕ КЛАВИШИ
    "org/gnome/shell/keybindings" = {
      toggle-message-tray = ["<Super>c"];
      show-screenshot-ui = ["<Super><Shift>s"];
    };

    # ИСПРАВЛЕНИЕ 2: Объединил настройки media-keys в один блок
    "org/gnome/settings-daemon/plugins/media-keys" = {
      screensaver = ["<Control><Alt>l"]; # Теперь блокировка не сотрется
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/"
      ];
    };
    
    # КАСТОМНЫЕ ШОРТКАТЫ (остаются без изменений)
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      binding = "<Super><Shift>t";
      command = "normcap";
      name = "NormCap";
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
      binding = "<Control><Alt>t";
      command = "kgx"; 
      name = "New Terminal";
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2" = {
      binding = "<Super>e";
      command = "nautilus"; 
      name = "File Manager";
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3" = {
      binding = "<Control><Alt>c";
      command = "dialect"; 
      name = "Dialect";
    };
  };

  programs.home-manager.enable = true;
  programs.bash.enable = true;
}

