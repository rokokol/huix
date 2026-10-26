{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  root = "${inputs.remotion-skills}/skills";
  skills = lib.mapAttrs (name: _: "${root}/${name}") (
    lib.filterAttrs (
      name: type: type == "directory" && builtins.pathExists "${root}/${name}/SKILL.md"
    ) (builtins.readDir root)
  );
in
{
  config = lib.mkIf config.rokokol.kdenlive.enable {
    home.packages = with pkgs; [
      nodejs
      ffmpeg-headless
    ];
    rokokol.agents = {
      inherit skills;
      skillGroups = lib.mapAttrs (_: _: "creative") skills;
    };
  };
}
