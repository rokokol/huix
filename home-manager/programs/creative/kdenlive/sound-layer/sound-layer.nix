{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  package = pkgs.callPackage ./package.nix {
    src = inputs.opus-sound-layer;
    pyloudnormSrc = inputs.pyloudnorm;
  };
  skill = pkgs.runCommandLocal "opus-sound-layer-skill" { } ''
    mkdir -p $out/references
    cp ${
      builtins.path {
        name = "sound-layer-skill";
        path = "${inputs.self}/home-manager/programs/creative/kdenlive/sound-layer/SKILL.md";
      }
    } $out/SKILL.md
    cp ${package}/share/opus-sound-layer/README.md $out/references/upstream.md
    cp ${package}/share/opus-sound-layer/PROMPT.md $out/references/PROMPT.md
  '';
in
{
  config = lib.mkIf config.rokokol.kdenlive.enable {
    home.packages = [ package ];
    rokokol.agents = {
      skills.opus-sound-layer = skill;
      skillGroups.opus-sound-layer = "creative";
    };
  };
}
