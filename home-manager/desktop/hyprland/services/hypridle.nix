{ ... }:

{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        # hyprlock-quote.sh detects a re-lock on its own by watching for a
        # change in the hyprlock PID — hypridle must not reset anything
        lock_cmd = "pidof hyprlock || hyprlock";
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
