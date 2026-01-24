{ lib, ... }:

{
  dconf.settings = {
    # --- Interface & Theme ---
    "org/gnome/desktop/interface" = {
      color-scheme = "default";
      icon-theme = "Papirus";
    };

    "org/gnome/desktop/search-providers" = {
      disabled = [ "org.gnome.Epiphany.desktop" ];
    };

    "org/gnome/shell/extensions/vitals" = {
      hot-sensors = [
        "_temperature_k10temp_tctl_"
        "_memory_usage_"
        "_processor_usage_"
        "_gpu#1_temperature_"
        "_gpu#1_memory_used_"
        "_gpu#1_utilization_"
      ];
      icon-style = 0;
    };

    # --- Extensions & Favorites ---
    "org/gnome/shell" = {
      favorite-apps = [
        "firefox.desktop"
        "org.gnome.Nautilus.desktop"
        "org.gnome.Console.desktop"
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
      show-screenshot-ui = [ "<Super><Shift>s" ];
    };

    "org/gnome/settings-daemon/plugins/media-keys" = {
      screensaver = [ "<Control><Alt>l" ];
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4/"
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
  };
}

