{ ... }:

{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        # Сброс состояния диалога при каждом локе: первый диалог = re-entry
        lock_cmd = ''pidof hyprlock || (rm -f ''${XDG_RUNTIME_DIR:-/tmp}/hypr-ddlc/state && hyprlock)'';
        before_sleep_cmd = "loginctl lock-session"; # block until the sleep
        after_sleep_cmd = "hyprctl dispatch dpms on"; # turn on the screen on wakeup
      };

      listener = [
        {
          timeout = 5400; # secs
          on-timeout = "loginctl lock-session";
        }
      ];
    };
  };
}
