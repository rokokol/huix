{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  package = pkgs.callPackage ./package.nix { src = inputs.rea-video; };
in
{
  options.rokokol.rea-video.enable =
    lib.mkEnableOption "rea-video, the shot-level video forensics CLI, with its skill"
    // {
      default = config.rokokol.workstation.enable;
    };

  config = lib.mkIf config.rokokol.rea-video.enable {
    home.packages = [ package ];

    rokokol.agents = {
      # The skill reads its references from beside itself, so the directory travels whole
      skills.rea-video = builtins.path {
        name = "rea-video-skill";
        path = "${inputs.rea-video}/skills/rea-video";
      };
      skillGroups.rea-video = "creative";
    };
  };
}
