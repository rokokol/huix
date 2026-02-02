{ lib, ... }:

{
  dconf.settings = {
    # --- Interface & Theme ---
    "org/gnome/desktop/interface" = {
      color-scheme = "default";
      icon-theme = "Papirus";
    };

    # Wallpaper
    "org/gnome/desktop/background" = {
      picture-uri = "file:///home/rokokol/huix/wallpaper_light.png";
      picture-uri-dark = "file:///home/rokokol/huix/wallpaper_dark.png";
      picture-options = "fill";
    };

    # Lock screen wallpaper
    "org/gnome/desktop/screensaver" = {
      picture-uri = "file:///home/rokokol/huix/wallpaper_light.png";
      picture-options = "fill";
    };

    "com/github/stunkymonkey/nautilus-open-any-terminal" = {
      terminal = "kitty";
      new-tab = false; # Open new term
      flatpak = "system";
    };

    "org/gnome/desktop/search-providers" = {
      disabled = [ "org.gnome.Epiphany.desktop" ];
    };

    "org/gnome/shell/extensions/vitals" = {
      hot-sensors = [
        "_temperature_k10temp_tctl_"
        "_memory_allocated_"
        "_processor_usage_"
        "_gpu#1_temperature_"
        "_gpu#1_memory_used_"
        "_gpu#1_utilization_"
      ];
      icon-style = 0;
    };

    # --- Power ---
    "org/gnome/settings-daemon/plugins/power" = {
      sleep-inactive-ac-timeout = 7200;
      sleep-inactive-battery-timeout = 7200;
      button-power-action = "suspend";
    };

    # --- Extensions & Favorites ---
    "org/gnome/shell" = {
      favorite-apps = [
        "firefox.desktop"
        "org.gnome.Nautilus.desktop"
        "AmneziaVPN.desktop"
        "obsidian.desktop"
      ];
      disable-user-extensions = false;
      enabled-extensions = [
        "GPaste@gnome-shell-extensions.gnome.org"
        "Vitals@CoreCoding.com"
      ];
    };

    # --- Window Behavior ---
    "org/gnome/shell/window-switcher" = {
      current-workspace-only = true;
    };

    "org/gnome/desktop/wm/keybindings" = {
      switch-applications = [ ];
      switch-applications-backward = [ ];
      switch-windows = [ "<Alt>Tab" ];
      switch-windows-backward = [ "<Shift><Alt>Tab" ];
    };

    # --- System Keybindings ---
    "org/gnome/shell/keybindings" = {
      toggle-message-tray = [ "<Super>c" ];
      # show-screenshot-ui = [ "<Super><Shift>s" ];
    };

    "org/gnome/settings-daemon/plugins/media-keys" = {
      screensaver = [ "<Control><Alt>l" ];
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5/"
      ];
    };

    # --- Custom Shortcuts Definitions ---
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      binding = "<Super><Shift>t";
      command = "normcap";
      name = "NormCap";
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
      binding = "<Control><Alt>t";
      command = "kitty";
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

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4" = {
      binding = "<Super><Shift>g";
      command = "PureRef";
      name = "PureRef";
    };

    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5" = {
      binding = "<Super><Shift>s";
      # command = "gradia --screenshot=INTERACTIVE";
      command = "script --command \"flameshot gui\" /dev/null";
      name = "Screenshot";
    };
  };
}

