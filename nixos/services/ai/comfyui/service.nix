{ config, lib, ... }:

let
  cfg = config.rokokol.comfyui;
in
{
  config = lib.mkIf cfg.enable {
    users.users.comfyui.group = "comfyui";
    users.groups.comfyui = { };

    services.comfyui = {
      enable = true;
      user = "comfyui";
      group = "comfyui";
      acceleration = "cuda";
      host = "127.0.0.1";
      inherit (cfg) port;
    };
  };
}
