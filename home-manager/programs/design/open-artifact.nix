{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  # Upstream ships the standalone skill inside its Codex bundle
  bundle = "open-artifact-plugins/codex";
  package =
    pkgs.runCommand "open-artifact"
      {
        nativeBuildInputs = with pkgs; [
          makeWrapper
          unzip
        ];
        meta = {
          description = "Local editors and agent skill for Open Artifact projects";
          homepage = "https://github.com/JimLiu/open-artifact";
          license = lib.licenses.asl20;
          mainProgram = "open-artifact";
        };
      }
      ''
        unzip -q ${inputs.open-artifact} '${bundle}/skills/open-artifact/*' \
          '${bundle}/LICENSE' '${bundle}/NOTICE'
        mkdir -p "$out/share" "$out/share/doc/open-artifact"
        mv '${bundle}/skills' "$out/share/skills"
        cp '${bundle}/LICENSE' '${bundle}/NOTICE' "$out/share/doc/open-artifact/"
        makeWrapper ${lib.getExe pkgs.nodejs} "$out/bin/open-artifact" \
          --add-flags "$out/share/skills/open-artifact/scripts/open-artifact.mjs"
      '';
in
{
  options.rokokol.open-artifact.enable = lib.mkEnableOption "Open Artifact and its local editors" // {
    default = config.rokokol.workstation.enable;
  };

  config = lib.mkIf config.rokokol.open-artifact.enable {
    home.packages = [
      package
      pkgs.nodejs
    ];

    rokokol.agents = {
      skills.open-artifact = "${package}/share/skills/open-artifact";
      skillGroups.open-artifact = "design";
    };

    # Pi has no adapter of its own, so an artifact it makes belongs to no conversation and a
    # request from the page waits in the shared inbox. This extension attaches the session and
    # answers the daemon; the Pi half of upstream's harness-node and harness-stdio examples
    home.file = lib.mkIf config.rokokol.pi.enable {
      "${config.programs.pi-coding-agent.configDir}/extensions/open-artifact.ts".source =
        ./open-artifact-pi.ts;
      "${config.programs.pi-coding-agent.configDir}/extensions/open-artifact-routing.ts".source =
        ./open-artifact-routing.ts;
    };

    programs.pi-coding-agent.settings.extensions = lib.mkIf config.rokokol.pi.enable [
      "${config.programs.pi-coding-agent.configDir}/extensions/open-artifact.ts"
    ];
  };
}
