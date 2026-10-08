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
  # How long an alert keeps trying a relay that does not answer. msmtp has no queue, so without
  # the retries an alert raised while the relay is down is lost
  retrySeconds = 24 * 3600;

  # Mails the status and the last journal lines of the unit named in $1 to root. The aliases
  # file maps root to the real address, so the address is not in the store
  composeAlert = pkgs.writeShellApplication {
    name = "alert-mail";
    runtimeInputs = [
      pkgs.coreutils
      config.systemd.package
    ];
    # The status holds UTF-8 such as the unit bullet, so the headers declare it. systemctl status
    # exits 3 for a failed unit, and that unit is the reason for the mail. The status is read
    # once, so a late delivery still shows the unit as it was when it failed, and a late subject
    # says which attempt got through and how late it is. msmtp exits 68, 69, 74 or 75 when the
    # relay cannot be found, refuses the mail, drops the line or does not answer; those are
    # retried, with a pause that doubles up to 15 minutes. Any other code is a fault in the
    # configuration or the message, which a retry does not repair
    text = ''
      unit=$1
      host=$(uname -n)
      status_text=$(systemctl status --full --no-pager --lines=50 -- "$unit" || true)
      attempt=1
      pause=30
      while :; do
        late=
        if ((attempt > 1)); then
          late=" (attempt $attempt, $(((SECONDS + 59) / 60)) min late)"
        fi
        status=0
        {
          printf 'To: root\n'
          printf 'Subject: [%s] %s failed%s\n' "$host" "$unit" "$late"
          printf 'MIME-Version: 1.0\n'
          printf 'Content-Type: text/plain; charset=UTF-8\n'
          printf 'Content-Transfer-Encoding: 8bit\n'
          printf '\n'
          printf '%s\n' "$status_text"
        } | sendmail -i -t || status=$?
        case $status in
          0) exit 0 ;;
          68 | 69 | 74 | 75) ;;
          *) exit "$status" ;;
        esac
        if ((SECONDS + pause > ${toString retrySeconds})); then
          printf 'alert-mail: the relay did not take the alert for %s, giving up\n' "$unit" >&2
          exit "$status"
        fi
        printf 'alert-mail: sendmail exited %s, next try in %s s\n' "$status" "$pause" >&2
        sleep "$pause"
        attempt=$((attempt + 1))
        pause=$((pause * 2 > 900 ? 900 : pause * 2))
      done
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

    # OnFailure=alert-mail@%n.service in a unit sends one mail for each failure. While an alert
    # waits for the relay, a new failure of the same unit joins it and sends no mail of its own
    systemd.services."alert-mail@" = {
      description = "Mail an alert that %i failed";

      # A flapping unit sends at most three mails an hour, and further starts fail. The retries
      # run inside one start, so they do not count against this limit
      startLimitIntervalSec = 3600;
      startLimitBurst = 3;

      # The sendmail wrapper lives here, and the unit PATH does not include it by default
      path = [ (dirOf config.security.wrapperDir) ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${lib.getExe composeAlert} %i";
        # The script stops retrying on its own; the timeout only catches a sendmail that hangs
        # past that point
        TimeoutStartSec = retrySeconds + 300;
      };
    };
  };
}
