{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.custom.btop;
in
{
  options.custom.btop.withCuda = lib.mkEnableOption "GPU-панель btop через btop-cuda";

  config.programs.btop = {
    enable = true;
    package = if cfg.withCuda then pkgs.btop-cuda else pkgs.btop;

    settings = {
      color_theme = "gruvbox_dark";
      cuda_support = cfg.withCuda;
      rocm_support = false;
      vim_keys = true;
    };
  };
}
