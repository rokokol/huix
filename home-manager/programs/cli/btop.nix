{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.rokokol.btop;
in
{
  options.rokokol.btop.withCuda = lib.mkEnableOption "btop GPU panel via btop-cuda";

  config = {
    programs.btop = {
      enable = true;
      package = if cfg.withCuda then pkgs.btop-cuda else pkgs.btop;

      settings = {
        color_theme = "ddlc-dark";
        cuda_support = cfg.withCuda;
        rocm_support = false;
        vim_keys = true;
      };
    };

    xdg.configFile."btop/themes/ddlc-dark.theme".source = inputs.ddlc-palette.lib.dist.btop.dark;
  };
}
