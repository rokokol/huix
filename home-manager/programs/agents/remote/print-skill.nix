{
  lib,
  pkgs,
  osConfig,
  ...
}:

let
  cfg = osConfig.rokokol.printer.client;
in
{
  config = lib.mkIf cfg.enable {
    rokokol.agents.skills.print = osConfig.rokokol.printer.skill;
    rokokol.agents.skillGroups.print = "remote";
    home.packages = with pkgs; [
      cups
      exiftool
      openssh
      trash-cli
    ];
    home.sessionVariables = {
      PRINT_HOST = if cfg.host == null then "" else cfg.host;
      PRINT_PREPARE_COMMAND = lib.escapeShellArgs cfg.prepareCommand;
    };
  };
}
