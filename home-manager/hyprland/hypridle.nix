{ ... }:
{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";       # start hyprlock
        before_sleep_cmd = "loginctl lock-session";    # block until the sleep
        after_sleep_cmd = "hyprctl dispatch dpms on";  # turn on the screen on wakeup
      };
  
      listener = [
        {
          timeout = 300; # secs
          on-timeout = "loginctl lock-session";
        }
      ];
    };
  };
}
