{ pkgs, inputs }:
# scripts/make-station-iso.sh with xorriso and the tools it calls on its PATH, so the flake's
# lock pins them and the shell it runs from needs none of them. The flake runs it as an app and
# the install test runs it to add its fixture secrets, so both go through the same command. The
# script and its lib are the only files copied, so an edit to another script moves nothing here
let
  scriptsDir = "${inputs.self}/scripts";
  scripts = builtins.path {
    name = "make-station-iso-scripts";
    path = scriptsDir;
    filter =
      path: _:
      builtins.elem (pkgs.lib.removePrefix "${scriptsDir}/" path) [
        "make-station-iso.sh"
        "lib"
        "lib/station-secrets.sh"
      ];
  };
in
pkgs.writeShellApplication {
  name = "make-station-iso";
  runtimeInputs = with pkgs; [
    coreutils
    gnugrep
    gnused
    gnutar
    xorriso
  ];
  text = ''exec bash ${scripts}/make-station-iso.sh "$@"'';
  meta = {
    description = "Copy the station's installer image with its secrets added inside";
    license = pkgs.lib.licenses.mit;
  };
}
