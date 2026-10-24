{
  config,
  lib,
  inputs,
  ...
}:

# The skills of the flake's skill-NAME inputs, each handed to the agents as NAME, for every home
# that imports this module and runs Claude Code. A skill comes from the store and cannot be
# written, so the notes and drafts a skill keeps go to the shared Claude Code directory, which
# Syncthing carries between the hosts. A token stays on its host: each app issues its own
let
  prefix = "skill-";
  available = lib.mapAttrs' (
    name: input: lib.nameValuePair (lib.removePrefix prefix name) input.outPath
  ) (lib.filterAttrs (name: _: lib.hasPrefix prefix name) inputs);
  skills = removeAttrs available config.rokokol.skills.exclude;
  stateDir = "${config.programs.claude-account.sharedDir}/skill-state";
in
{
  options.rokokol.skills.exclude = lib.mkOption {
    type = lib.types.listOf (lib.types.enum (lib.attrNames available));
    default = [ ];
    example = [ "super-productivity" ];
    description = "Skills of the flake's skill-NAME inputs that this home leaves out";
  };

  config = lib.mkIf config.rokokol.claude.enable {
    rokokol.agents.skills = skills;

    home.sessionVariables =
      lib.optionalAttrs (skills ? contributing) {
        CONTRIB_HOME = "${stateDir}/contributing";
      }
      // lib.optionalAttrs (skills ? super-productivity) {
        SP_HOME = "${stateDir}/super-productivity";
        SP_TOKEN_FILE = "${config.xdg.configHome}/super-productivity-skill/secrets/token";
      };
  };
}
