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
    settings:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = agentPkgs;
      extraSpecialArgs = {
        huixDir = "/build/pi-test/huix";
        myWikiDir = "/build/pi-test/myWiki";
        projectsDirs = [ "/build/pi-test/Projects" ];
        osConfig = {
          rokokol.pi.enable = true;
          sops.secrets."openrouter-pi-key".path = "/run/secrets/pi-fixture-key";
        };
      };
      modules = [
        ../../home-manager/programs/agents/agents.nix
        ../../home-manager/programs/agents/pi.nix
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
                opencode.command = "opencode-mcp";
              };
            };
          };
        }
      ];
    };
  base = (home { }).config;
  changed = (home { theme = "dark"; }).config;
  directory = base.programs.pi-coding-agent.configDir;
  fixture = json.generate "pi-config-fixture.json" {
    inherit directory;
    settings = base.home.file."${directory}/settings.json".source;
    models = base.home.file."${directory}/models.json".source;
    keybindings = base.home.file."${directory}/keybindings.json".source;
    headsUp = base.home.file."${directory}/configs/heads-up.json".source;
    hoster = base.home.file."${directory}/extensions/hoster.ts".source;
    modules = base.home.file."${directory}/modules.json".source;
    automode = builtins.fromJSON base.home.sessionVariables.PI_AUTOMODE_SETTINGS_JSON;
    groups = base.rokokol.agents.piPackages;
    activation = pkgs.writeText "pi-settings-activation.sh" base.home.activation.piSettings.data;
    changedActivation = pkgs.writeText "pi-settings-changed.sh" changed.home.activation.piSettings.data;
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
