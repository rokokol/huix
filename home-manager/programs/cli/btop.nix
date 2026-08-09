{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.rokokol.btop;
in
{
  options.rokokol.btop.withCuda = lib.mkEnableOption "btop GPU panel via btop-cuda";

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
