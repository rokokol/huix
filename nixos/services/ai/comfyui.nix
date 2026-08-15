{
  config,
  lib,
  rokokolName,
  ...
}:

let
  port = 8188;
in
{
  options.rokokol.comfyui.enable = lib.mkEnableOption "ComfyUI (CUDA)";

  config = lib.mkIf config.rokokol.comfyui.enable {
    # CUDA comes from the torch-bin overlay in flake.nix; --lowvram keeps the weights off the
    # 12 GiB card so Flux-sized models fit
    services.comfyui = {
      enable = true;
      inherit port;

      extraArgs = [
        "--lowvram"
        "--base-directory=/home/${rokokolName}/comfyui-data"
      ];
    };

    environment.sessionVariables = {
      COMFYUI_PORT = port;
    };
  };
}
