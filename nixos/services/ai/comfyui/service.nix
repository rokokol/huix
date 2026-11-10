{
  config,
  lib,
  rokokolName,
  ...
}:

let
  cfg = config.rokokol.comfyui;
in
{
  config = lib.mkIf cfg.enable {
    services.comfyui = {
      enable = true;
      user = "comfyui";
      group = "comfyui";
      acceleration = "cuda";
      host = "127.0.0.1";
      # The module's own state directory lives under /var/lib/private, which systemd holds at
      # 0700, so the owner needs root to add a model. /srv/comfyui is created 2770 for the group
      home = "/srv/comfyui";
      inherit (cfg) port;
    };

    users.groups.comfyui = { };

    users.users = {
      comfyui.group = "comfyui";
      ${rokokolName}.extraGroups = [ "comfyui" ];
    }
    # The station's agent logs in here over Tailscale SSH as its own user and adds models by hand
    // lib.optionalAttrs (config.rokokol.mya-agent.enable || config.rokokol.mya-agent.guest.enable) {
      ${config.rokokol.mya-agent.user}.extraGroups = [ "comfyui" ];
    };

    systemd.services.comfyui.serviceConfig = {
      # The module writes with UMask 0077, which leaves the outputs unreadable for the owner
      UMask = lib.mkForce "0007";

      # The wrapper copies its source tree into the data directory at every start. Inside a user
      # namespace the real uid is not mapped, so the files the copy makes appear owned by nobody
      # and the copy cannot set their modes: the unit fails with EPERM on the first start
      PrivateUsers = lib.mkForce false;
    };
  };
}
