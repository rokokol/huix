{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Seconds without input before the screen goes dark and the session counts as idle
  idleAfter = 600;

  # hypridle runs outside the graphical session, so it names the session logind keeps as the
  # user's display rather than its own. Anyone reads the hint, and the agent's power units wait
  # for it before a sleep, a shutdown or a restart
  idleHint = pkgs.writeShellScript "idle-hint" ''
    set -eu
    session=$(${pkgs.systemd}/bin/loginctl show-user "$(${pkgs.coreutils}/bin/id -un)" -p Display --value)
    path=$(${pkgs.systemd}/bin/busctl call org.freedesktop.login1 /org/freedesktop/login1 \
      org.freedesktop.login1.Manager GetSession s "$session" | ${pkgs.gawk}/bin/awk '{ gsub(/"/, "", $2); print $2 }')
    exec ${pkgs.systemd}/bin/busctl call org.freedesktop.login1 "$path" \
      org.freedesktop.login1.Session SetIdleHint b "$1"
  '';
in
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
          timeout = idleAfter;
          on-timeout = "hyprctl dispatch 'hl.dsp.dpms({ action = \"off\" })'";
          on-resume = "hyprctl dispatch 'hl.dsp.dpms({ action = \"on\" })'";
        }
        {
          timeout = idleAfter;
          on-timeout = "${idleHint} true";
          on-resume = "${idleHint} false";
        }
        {
          timeout = 5400; # secs
          on-timeout = "loginctl lock-session";
        }
      ];
    };
  };
}
