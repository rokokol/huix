{ config, ... }:

{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        # every lock path funnels through here, so this is where the dialog
        # animation is started; it blocks for the whole lock, like hyprlock did
        lock_cmd = "pidof hyprlock || ${config.ddlc.hyprlock.lockCommand}";
        before_sleep_cmd = "loginctl lock-session"; # block until the sleep
        after_sleep_cmd = "hyprctl dispatch dpms on"; # turn on the screen on wakeup
      };

      listener = [
        {
          # blanking is independent of locking: without it the monitor stayed lit
          # forever after a lock and the GPU kept compositing the shader.
          # hypridle honours dbus idle inhibitors, so video keeps the screen awake
          timeout = 600;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
        {
          timeout = 5400; # secs
          on-timeout = "loginctl lock-session";
        }
      ];
    };
  };
}
