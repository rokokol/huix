{ ... }:

{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        # hyprlock-guard (см. hyprlock.nix) перезапускает hyprlock при краше,
        # чтобы залоченная сессия не оставалась без локера
        lock_cmd = "pidof hyprlock || hyprlock-guard";
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
