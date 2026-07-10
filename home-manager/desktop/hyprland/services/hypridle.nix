{ ... }:

{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        # Реплику перезахода при новом локе hyprlock-quote.sh определяет сам
        # по смене PID hyprlock — hypridle ничего сбрасывать не должен.
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
