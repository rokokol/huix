{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  options.rokokol.kinship-research.enable = lib.mkEnableOption "the ex-USSR kinship research skill";

  config = lib.mkIf config.rokokol.kinship-research.enable {
    home.packages = with pkgs; [ chromium ];
    home.sessionVariables.CHROME_PATH = lib.getExe pkgs.chromium;
    rokokol.agents = {
      skills.ex-ussr-kinship-research = inputs.ex-ussr-kinship-research;
      skillGroups.ex-ussr-kinship-research = "deep-research";
    };
  };
}
