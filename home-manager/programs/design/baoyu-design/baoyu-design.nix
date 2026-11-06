{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

# The local build of claude.ai's Artifact types: a slide deck, a canvas, a design system, a
# dashboard and a motion film, each written as files in a folder and opened in the editor that
# reads them. The editors are prebuilt pages, so node alone runs them. Upstream ships the
# editors, the icons and the type references under Anthropic's terms and its own MIT covers only
# the local tooling; NOTICE.md in the input spells out which is which
let
  root = "${inputs.baoyu-design}/skills";
  skills = lib.mapAttrs (name: _: "${root}/${name}") (
    lib.filterAttrs (
      name: type: type == "directory" && builtins.pathExists "${root}/${name}/SKILL.md"
    ) (builtins.readDir root)
  );
in
{
  options.rokokol.baoyu-design.enable =
    lib.mkEnableOption "claude.ai's Artifact types as local skills, with their editors"
    // {
      default = config.rokokol.workstation.enable;
    };

  config = lib.mkIf config.rokokol.baoyu-design.enable {
    home.packages = with pkgs; [ nodejs ];

    rokokol.agents = {
      inherit skills;
      skillGroups = lib.mapAttrs (_: _: "design") skills;
    };
  };
}
