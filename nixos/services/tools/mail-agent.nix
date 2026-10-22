{
  config,
  lib,
  rokokolName,
  ...
}:

# The seam for the mail skill's service. The module owns the unit, the isolation and
# every default; this file supplies the two things it ships none of — where the mailboxes
# come from, and who may talk to the socket. Read the module's own options before adding
# a line here. The mailboxes are one private file, passwords and own addresses included,
# because this repository is public and the addresses are not
{
  options.rokokol.mail-agent.enable = lib.mkEnableOption "the mail agent service";

  config = lib.mkIf config.rokokol.mail-agent.enable {
    # The whole value is the mailbox file, so the key names nothing about the mailboxes
    sops.secrets."mail-agent" = {
      sopsFile = ../../../secrets/mail-agent.yaml;
      key = "config";
    };

    services.mail-agent = {
      enable = true;
      configFile = config.sops.secrets."mail-agent".path;
      socketUser = rokokolName;
    };
  };
}
