{
  config,
  lib,
  pkgs,
  osConfig,
  inputs,
  ...
}:
let
  server = inputs.self.nixosConfigurations.nixos-station.config;
  memory = server.rokokol.hindsight;
  cfg = config.programs.pi-coding-agent;
in
{
  config =
    lib.mkIf (config.rokokol.pi.enable && (osConfig.rokokol.hindsight.client.enable or false))
      {
        programs.pi-coding-agent.settings.extensions = [ "${cfg.configDir}/extensions/memory.ts" ];
        home.file."${cfg.configDir}/extensions/memory.ts".source = pkgs.replaceVars ./memory.ts {
          url = "http://${server.networking.hostName}:${toString memory.publicPort}/mcp/${memory.bank}/";
          tokenFile = osConfig.sops.secrets.hindsight-client-token.path;
        };
      };
}
