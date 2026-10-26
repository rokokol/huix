{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  config = lib.mkIf config.rokokol.kdenlive.enable {
    home.packages = with pkgs; [
      nodejs
      chromium
    ];
    home.sessionVariables.CHROME_PATH = lib.getExe pkgs.chromium;
    rokokol.agents = {
      skills.anatomy = inputs.anatomy;
      skillGroups.anatomy = "creative";
    };
  };
}
