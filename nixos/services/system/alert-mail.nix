{
  config,
  lib,
  pkgs,
  ...
}:

# Alert e-mail for a host with no desktop to show a notification on. msmtp becomes the system
# sendmail, so smartd and alert-mail@ reach an SMTP relay through it. The relay and the real
# recipient are private: both arrive through sops and never enter the store
let
  # Mails the status and the last journal lines of the unit named in $1 to root. The aliases
  # file maps root to the real address, so the address is not in the store
  composeAlert = pkgs.writeShellApplication {
    name = "alert-mail";
    runtimeInputs = [
      pkgs.coreutils
      config.systemd.package
    ];
    # The status holds UTF-8 such as the unit bullet, so the headers declare it. systemctl status
    # exits 3 for a failed unit, and that unit is the reason for the mail
    text = ''
      unit=$1
      host=$(uname -n)
      {
        printf 'To: root\n'
        printf 'Subject: [%s] %s failed\n' "$host" "$unit"
        printf 'MIME-Version: 1.0\n'
        printf 'Content-Type: text/plain; charset=UTF-8\n'
        printf 'Content-Transfer-Encoding: 8bit\n'
        printf '\n'
        systemctl status --full --no-pager --lines=50 -- "$unit" || true
      } | sendmail -i -t
    '';
  };
in
{
  options.rokokol.alert-mail.enable = lib.mkEnableOption "alert e-mail through an SMTP relay";

  config = lib.mkIf config.rokokol.alert-mail.enable {
    sops.secrets."alert-mail-msmtprc" = { };
    sops.secrets."alert-mail-aliases" = { };

    # The secret is the account part of a msmtp configuration, in any shape the relay needs.
    # The defaults here are the lines that depend on this module, such as the aliases path.
    # msmtp has no network timeout by default, so a dead relay holds sendmail for minutes
    sops.templates."alert-mail-msmtprc" = {
      path = "/etc/msmtprc";
      content = ''
        defaults
        aliases ${config.sops.secrets."alert-mail-aliases".path}
        syslog LOG_MAIL
        timeout 30

        ${config.sops.placeholder."alert-mail-msmtprc"}
      '';
    };

    # programs.msmtp supplies the sendmail wrapper. It renders /etc/msmtprc into the store, and
    # msmtp reads no other system path, so the sops template takes that path instead
    programs.msmtp.enable = true;
    environment.etc."msmtprc".enable = false;

    # OnFailure=alert-mail@%n.service in a unit sends one mail for each failure
    systemd.services."alert-mail@" = {
      description = "Mail an alert that %i failed";

      # A flapping unit sends at most three mails an hour, and further starts fail
      startLimitIntervalSec = 3600;
      startLimitBurst = 3;

      # The sendmail wrapper lives here, and the unit PATH does not include it by default
      path = [ (dirOf config.security.wrapperDir) ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${lib.getExe composeAlert} %i";
        # A oneshot has no start timeout by default, and a dead relay must not hold the unit
        TimeoutStartSec = "2min";
      };
    };
  };
}
