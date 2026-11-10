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
    users.users.comfyui.group = "comfyui";
    users.users.${rokokolName}.extraGroups = [ "comfyui" ];

    # The module writes with UMask 0077, which leaves the outputs unreadable for the owner
    systemd.services.comfyui.serviceConfig.UMask = lib.mkForce "0007";
  };
}
