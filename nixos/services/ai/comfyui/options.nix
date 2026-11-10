{ lib, ... }:

{
  options.rokokol.comfyui = {
    enable = lib.mkEnableOption "ComfyUI with declarative custom nodes";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8188;
      description = "Loopback port ComfyUI binds";
    };

    publicPort = lib.mkOption {
      type = lib.types.port;
      default = 8189;
      description = "Tailnet port ComfyUI publishes";
    };
  };
}
