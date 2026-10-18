{
  config,
  lib,
  pkgs,
  ...
}:

# Super Productivity with no screen, so that an agent reads and adds tasks through its REST API.
# The API hands each request to the app's window, so the app runs on a virtual display
let
  cfg = config.rokokol.super-productivity;
  name = "super-productivity";
  profile = "/var/lib/${name}/profile";
  display = ":99";

  start = pkgs.writeShellScript "super-productivity-headless" ''
    set -eu
    ${lib.getExe' pkgs.xorg.xorgserver "Xvfb"} ${display} -nolisten tcp -screen 0 1280x800x24 &
    until [ -S /tmp/.X11-unix/X${lib.removePrefix ":" display} ]; do sleep 0.2; done
    # The host has no GPU, and Chromium restarts a GPU process that cannot start again and again
    exec ${lib.getExe pkgs.super-productivity} --user-data-dir=${profile} --disable-gpu
  '';
in
{
  options.rokokol.super-productivity = {
    headless.enable = lib.mkEnableOption "Super Productivity on a virtual display, for its REST API";

    user = lib.mkOption {
      type = lib.types.str;
      description = "The user the app runs as, who reads the REST API's token in `tokenFile`";
    };

    setupUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Users who reach the VNC socket of the one-time setup";
    };

    tokenFile = lib.mkOption {
      type = lib.types.path;
      default = "${profile}/local-rest-api-token";
      readOnly = true;
      description = "The REST API's token, which the app writes once the API is turned on";
    };
  };

  config = lib.mkIf cfg.headless.enable {
    users.groups."${name}-vnc".members = cfg.setupUsers;

    systemd.services.${name} = {
      description = "Super Productivity on a virtual display";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      environment.DISPLAY = display;
      serviceConfig = {
        User = cfg.user;
        StateDirectory = name;
        StateDirectoryMode = "0700";
        ExecStart = start;
        Restart = "always";
        RestartSec = 10;
        # SuperSync's socket gives up after a run of failed reconnects, and nothing polls after
        # that; a daily start keeps a long outage from leaving the tasks stale for good
        RuntimeMaxSec = "1d";
        MemoryMax = "1G";
      };
    };

    # The sync account and its encryption password are typed once into the app. Start this unit,
    # forward its socket over SSH and point a VNC viewer at the local end
    systemd.services."${name}-vnc" = {
      description = "VNC to Super Productivity's virtual display, for its one-time setup";
      bindsTo = [ "${name}.service" ];
      after = [ "${name}.service" ];
      serviceConfig = {
        User = cfg.user;
        # The socket's group, so that `setupUsers` reach it
        Group = "${name}-vnc";
        UMask = "0007";
        RuntimeDirectory = "${name}-vnc";
        RuntimeDirectoryMode = "0770";
        ExecStart = "${lib.getExe pkgs.x11vnc} -display ${display} -unixsock /run/${name}-vnc/socket -rfbport 0 -forever -shared";
        # x11vnc answers the stop's SIGTERM with exit status 2
        SuccessExitStatus = 2;
      };
    };
  };
}
