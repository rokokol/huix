{ config, lib, ... }:

lib.mkIf config.rokokol.hyprland.enable {
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        # every lock path funnels through here, so this is where the dialog
        # animation is started; it blocks for the whole lock, like hyprlock did
        lock_cmd = "pidof hyprlock || ${config.ddlc.hyprlock.lockCommand}";
        # The session locks before the host sleeps, so it never wakes unlocked
        before_sleep_cmd = "loginctl lock-session";
        # The blanking listener below turns the screen off, and a wake leaves it off
        after_sleep_cmd = "hyprctl dispatch 'hl.dsp.dpms({ action = \"on\" })'";
      };

      listener = [
        {
          # blanking is independent of locking: without it the monitor stayed lit
          # forever after a lock and the GPU kept compositing the shader.
          # hypridle honours dbus idle inhibitors, so video keeps the screen awake
          timeout = 600;
          on-timeout = "hyprctl dispatch 'hl.dsp.dpms({ action = \"off\" })'";
          on-resume = "hyprctl dispatch 'hl.dsp.dpms({ action = \"on\" })'";
        }
        {
          timeout = 5400; # secs
          on-timeout = "loginctl lock-session";
        }
      ];
    };
  };
}
