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
    # The service writes with UMask 0077 and owns the state, so the owner needs the group bit to
    # add models by hand; this rule and the umask override are the only places that widen it
    systemd.tmpfiles.settings."10-comfyui" = {
      "/srv/comfyui".d = {
        user = "comfyui";
        group = "comfyui";
        mode = "2770";
      };
      "/home/${rokokolName}/comfyui-data" = {
        "L+" = {
          argument = "/srv/comfyui";
        };
      };
    };
  };
}
