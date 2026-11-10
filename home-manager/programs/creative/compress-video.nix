{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

# Upstream holds one skill among several in a single tree, so no skill-NAME input names it and the
# directory is written out here. FFmpeg comes with the skill: the skill only picks its flags
let
  skill = builtins.path {
    name = "compress-video-skill";
    path = "${inputs.pixel-point-skills}/skills/compress-video";
  };
in
{
  options.rokokol.compress-video.enable =
    lib.mkEnableOption "the compress-video skill and FFmpeg"
    // {
      default = config.rokokol.workstation.enable;
    };

  config = lib.mkIf config.rokokol.compress-video.enable {
    home.packages = with pkgs; [ ffmpeg-headless ];

    rokokol.agents.skills.compress-video = skill;
  };
}
