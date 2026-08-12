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
  imports = [ inputs.ddlc-terminal-themes.homeManagerModules.default ];

  options.rokokol.btop.withCuda = lib.mkEnableOption "btop GPU panel via btop-cuda";

  config = {
    # Deploys both variants and names the dark one — the theme owns its own file name
    ddlc.btop.enable = true;

    programs.btop = {
      enable = true;
      package = if cfg.withCuda then pkgs.btop-cuda else pkgs.btop;

      settings = {
        cuda_support = cfg.withCuda;
        rocm_support = false;
        vim_keys = true;
      };
    };
  };
}
