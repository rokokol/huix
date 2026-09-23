{
  config,
  lib,
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
in
{
  options.rokokol.telegram-agent.enable = lib.mkEnableOption "the Telegram agent service";

  config = lib.mkIf cfg.enable {
    sops.secrets."telegram-api-id" = { };
    sops.secrets."telegram-api-hash" = { };

    services.tg-agent = {
      enable = true;
      apiIdFile = config.sops.secrets."telegram-api-id".path;
      apiHashFile = config.sops.secrets."telegram-api-hash".path;
      socketUser = rokokolName;
    };
  };
}
