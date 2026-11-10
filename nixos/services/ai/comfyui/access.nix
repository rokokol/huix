{ config, lib, ... }:

let
  cfg = config.rokokol.comfyui;
in
{
  config = lib.mkIf cfg.enable {
    environment.sessionVariables = {
      COMFYUI_PORT = toString cfg.port;
    };

    rokokol.tailnet-web.sites.comfyui = {
      port = cfg.publicPort;
      backend = "http://127.0.0.1:${toString cfg.port}";
      extraConfig = ''
        client_max_body_size 512m;
        proxy_read_timeout 900s;
      '';
    };
  };
}
