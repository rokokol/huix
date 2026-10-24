{
  config,
  lib,
  inputs,
  rokokolName,
  ...
}:

# The seam for the telegram skill's service. The module owns the unit, the isolation and
# every default; this file supplies the two things it ships none of — where the api pair
# comes from, and who may talk to the socket. Read the module's own options before adding
# a line here: the permissions directory, the outbox and the sweep are already its own.
# One account, one session per host that runs this, so it is gated rather than shared
let
  cfg = config.rokokol.telegram-agent;
  secretsFile = builtins.path {
    name = "telegram-agent.yaml";
    path = "${inputs.self}/secrets/telegram-agent.yaml";
  };
in
{
  options.rokokol.telegram-agent = {
    enable = lib.mkEnableOption "the Telegram agent service";
    socketUser = lib.mkOption {
      type = lib.types.str;
      default = rokokolName;
      description = "The user who may access the Telegram socket and receives its skill";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets."telegram-api-id".sopsFile = secretsFile;
    sops.secrets."telegram-api-hash".sopsFile = secretsFile;

    services.tg-agent = {
      enable = true;
      apiIdFile = config.sops.secrets."telegram-api-id".path;
      apiHashFile = config.sops.secrets."telegram-api-hash".path;
      inherit (cfg) socketUser;
    };
  };
}
