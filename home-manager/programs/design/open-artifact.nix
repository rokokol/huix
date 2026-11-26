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
  };
}
