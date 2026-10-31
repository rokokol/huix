{
  config,
  lib,
  pkgs,
  piSharedDir,
  ...
}:
let
  instructions = "${config.xdg.configHome}/agents/AGENTS.md";
  sharedInstructions = "${piSharedDir}/AGENTS.md";
  ignores = pkgs.writeText "pi-shared-ignores" ''
    !/.stignore-shared
    !/AGENTS.md
    !/agents
    !/agents/**
    !/prompts
    !/prompts/**
    !/preferences
    !/preferences/**
    !/skill-state
    !/skill-state/**
    **
  '';
in
{
  config = lib.mkIf config.rokokol.pi.enable {
    programs.pi-coding-agent.settings.packages = [ piSharedDir ];
    # The skill state rides the same folder, so the owner's drafts and standing permissions
    # follow the owner from host to host; an agent's own home keeps its state to itself
    rokokol.agents.skillState = "${piSharedDir}/skill-state";
    home.file = {
      ${instructions}.source = config.lib.file.mkOutOfStoreSymlink sharedInstructions;
      "${piSharedDir}/package.json".source = (pkgs.formats.json { }).generate "pi-shared-package.json" {
        name = "@huix/pi-shared";
        pi = {
          agents = [ "./agents" ];
          prompts = [ "./prompts" ];
        };
      };
    };
    home.activation.piSharedState = lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] ''
      ${pkgs.coreutils}/bin/install -d -m 0700 ${lib.escapeShellArg piSharedDir} \
        ${lib.escapeShellArg "${piSharedDir}/agents"} ${lib.escapeShellArg "${piSharedDir}/prompts"} \
        ${lib.escapeShellArg "${piSharedDir}/preferences"} ${lib.escapeShellArg "${piSharedDir}/skill-state"}
      original=${lib.escapeShellArg instructions}
      shared=${lib.escapeShellArg sharedInstructions}
      if [ -f "$original" ]; then
        if [ ! -e "$shared" ]; then
          ${pkgs.coreutils}/bin/install -m 0600 "$original" "$shared"
        elif ! ${pkgs.diffutils}/bin/cmp -s "$original" "$shared"; then
          echo "Local and shared AGENTS.md differ; merge them before activation" >&2
          exit 1
        fi
      fi
      ${pkgs.coreutils}/bin/install -m 0600 ${ignores} ${lib.escapeShellArg "${piSharedDir}/.stignore-shared"}
      target=${lib.escapeShellArg "${piSharedDir}/.stignore"}
      if [ "$(${pkgs.coreutils}/bin/head -n 1 "$target" 2>/dev/null || true)" != '#include .stignore-shared' ]; then
        temporary="$(${pkgs.coreutils}/bin/mktemp "$target.XXXXXX")"
        printf '%s\n' '#include .stignore-shared' >"$temporary"
        if [ -e "$target" ]; then
          ${pkgs.gnused}/bin/sed '/^#include \.stignore-shared$/d' "$target" >>"$temporary"
        fi
        ${pkgs.coreutils}/bin/mv "$temporary" "$target"
      fi
    '';
  };
}
