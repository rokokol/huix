{
  pkgs,
  inputs,
  rokokolName,
  ...
}:
# nix flake check already evaluates every host. The nixvim entries add the one thing
# evaluation cannot say: whether the Lua nixvim assembles out of every module is
# parseable — nixvim runs stylua over the generated init.lua, so a syntax error fails
# the build. The station's VM test is not here; flake.nix says why
# nix-lint holds every .nix file here to the standard the skill carries. It runs in a
# build sandbox, so it leaves out the rules that need this flake's inputs; the eval
# job runs the whole checker through apps.check-nix, where the inputs are there
pkgs.lib.mapAttrs' (
  name: cfg:
  pkgs.lib.nameValuePair "nixvim-init-${name}"
    cfg.config.home-manager.users.${rokokolName}.programs.nixvim.build.initFile
) inputs.self.nixosConfigurations
// {
  nix-lint = inputs.nix-best-practices.lib.mkCheck {
    inherit pkgs;
    root = ./.;
    namespaces = [ "rokokol" ];
  };

  # The scripts against stubbed commands: every keyword rotate-screen.sh and
  # tablet-mode.sh emit is asserted here, where there is no compositor to ask.
  # make-station-iso.sh runs the real xorriso on a small image
  script-tests =
    pkgs.runCommand "script-tests"
      {
        nativeBuildInputs = with pkgs; [
          jq
          xorriso
        ];
        scripts = builtins.path {
          name = "huix-scripts";
          path = ./scripts;
        };
      }
      ''
        bash "$scripts/tests/run.sh"
        touch "$out"
      '';

  # The pure half of yazi's own plugins, under plain Lua with yazi's globals stubbed
  yazi-plugin-tests =
    pkgs.runCommand "yazi-plugin-tests"
      {
        nativeBuildInputs = with pkgs; [ lua5_4 ];
        plugins = builtins.path {
          name = "huix-yazi-plugins";
          path = ./home-manager/programs/yazi/plugins;
        };
      }
      ''
        for test in "$plugins"/*/test.lua; do
          (cd "$(dirname "$test")" && lua test.lua)
        done
        touch "$out"
      '';
}
