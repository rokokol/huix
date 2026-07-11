{ huixDir, ... }:

{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        # Обёртка lock: готовит первый кадр диалога (пустой бокс) и exec
        # hyprlock; реплику перезахода скрипт запускает сам по смене PID.
        lock_cmd = "pidof hyprlock || ${huixDir}/scripts/hyprlock-quote.sh lock";
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
