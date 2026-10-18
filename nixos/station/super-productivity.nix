{
  config,
  lib,
  rokokolName,
  ...
}:

# The owner's tasks for the Telegram agent: Super Productivity syncs here with no screen, as the
# agent's user, and the agent's skill reads the REST token from the app's profile
let
  agent = config.rokokol.mya-agent;
  sp = config.rokokol.super-productivity;
in
lib.mkIf agent.enable {
  rokokol.super-productivity = {
    headless.enable = true;
    inherit (agent) user;
    setupUsers = [ rokokolName ];
  };

  systemd.services.mya-agent.environment.SP_TOKEN_FILE = sp.tokenFile;
}
