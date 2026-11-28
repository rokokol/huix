{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  agentPkgs = inputs.self.nixosConfigurations.nixos-pc.pkgs;
  json = pkgs.formats.json { };
  home =
    settings: openArtifact:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = agentPkgs;
      extraSpecialArgs = {
        inherit inputs;
        huixDir = "/build/pi-test/huix";
        myWikiDir = "/build/pi-test/myWiki";
        piSharedDir = "/build/pi-test/.local/share/pi-shared";
        projectsDirs = [ "/build/pi-test/Projects" ];
        osConfig = {
          rokokol.pi.enable = true;
          sops.secrets."openrouter-pi-key".path = "/run/secrets/pi-fixture-key";
        };
      };
      modules = [
        ../../home-manager/programs/agents/agents.nix
        ../../home-manager/programs/agents/pi
        ../../home-manager/programs/design
        {
          options.rokokol.workstation.enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          config = {
            home = {
              username = "pi-test";
              homeDirectory = "/build/pi-test";
              stateVersion = "26.05";
            };
            rokokol = {
              pi.enable = true;
              open-artifact.enable = openArtifact;
              agents = {
                groups = {
                  research = "Research tools";
                  empty = "An empty group";
                };
                skills.example = pkgs.writeTextDir "SKILL.md" ''
                  ---
                  name: example
                  description: A fixture skill for Pi package discovery
                  ---
                  Read the fixture
                '';
                skillGroups.example = "research";
                mcpGroups.remote = "research";
              };
            };
            programs = {
              pi-coding-agent = { inherit settings; };
              mcp.servers = {
                local = {
                  command = "example-mcp";
                  env.TOKEN.file = "/run/secrets/pi-fixture";
                };
                remote.url = "http://127.0.0.1:9/mcp";
                disabled = {
                  command = "disabled-mcp";
                  enabled = false;
                };
              };
            };
          };
        }
      ];
    };
  base = (home { } true).config;
  changed = (home { theme = "dark"; } true).config;
  disabled = (home { } false).config;
  directory = base.programs.pi-coding-agent.configDir;
  fixture = json.generate "pi-config-fixture.json" {
    inherit directory;
    settings = base.home.file."${directory}/settings.json".source;
    models = base.home.file."${directory}/models.json".source;
    keybindings = base.home.file."${directory}/keybindings.json".source;
    hoster = base.home.file."${directory}/extensions/hoster.ts".source;
    modules = base.home.file."${directory}/modules.json".source;
    # The same map the settings were built from, so a test compares against it and not a copy
    routes = (import ../../lib/ai-models.nix).chat;
    groups = base.rokokol.agents.piPackages;
    disabledPackages = disabled.programs.pi-coding-agent.settings.packages;
    disabledModules = disabled.home.file."${directory}/modules.json".source;
    artifactFiles = lib.filter (lib.hasPrefix "${directory}/extensions/open-artifact") (
      lib.attrNames base.home.file
    );
    activation = pkgs.writeText "pi-settings-activation.sh" base.home.activation.piSettings.data;
    changedActivation = pkgs.writeText "pi-settings-changed.sh" changed.home.activation.piSettings.data;
    sharedActivation = pkgs.writeText "pi-shared-activation.sh" base.home.activation.piSharedState.data;
    backupActivation = pkgs.writeText "pi-backup-activation.sh" base.home.activation.piBackupIgnores.data;
    sharedPackage = base.home.file."/build/pi-test/.local/share/pi-shared/package.json".source;
  };
  test = builtins.path {
    name = "test-pi-config.py";
    path = ./test-pi-config.py;
  };
in
pkgs.runCommand "pi-config-tests" { nativeBuildInputs = with pkgs; [ python3 ]; } ''
  python3 -B ${test} ${fixture}
  touch "$out"
''
