{ config, lib, ... }:

let
  port = 8188;
in
{
  options.rokokol.comfyui.enable = lib.mkEnableOption "ComfyUI (CUDA)";

  config = lib.mkIf config.rokokol.comfyui.enable {
    services.comfyui = {
      enable = true;
      inherit port;

      extraArgs = [ "--lowvram" ];
    };

    environment.sessionVariables = {
      COMFYUI_PORT = port;
    };
  };
}
