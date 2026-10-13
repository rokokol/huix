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

  # Passes the message on stdin and the arguments to sendmail until the relay takes it. The
  # message is read once, and a late subject says which attempt got through and how late it is.
  # msmtp exits 68, 69, 74 or 75 when the relay cannot be found, refuses the mail, drops the line
  # or does not answer; those are retried, with a pause that doubles up to 15 minutes. Any other
  # code is a fault in the configuration or the message, which a retry does not repair
  sendmailRetry = pkgs.writeShellApplication {
    name = "sendmail-retry";
    runtimeInputs = with pkgs; [
      coreutils
      gnused
    ];
    text = ''
      message=$(cat)
      attempt=1
      pause=30
      while :; do
        late=
        if ((attempt > 1)); then
          late=" (attempt $attempt, $(((SECONDS + 59) / 60)) min late)"
        fi
        status=0
        # The subject is changed in the header only, which ends at the first empty line
        printf '%s\n' "$message" \
          | sed "1,/^\$/ s/^Subject: .*/&$late/" \
          | ${config.security.wrapperDir}/sendmail "$@" || status=$?
        case $status in
          0) exit 0 ;;
          68 | 69 | 74 | 75) ;;
          *) exit "$status" ;;
        esac
        if ((SECONDS + pause > ${toString retrySeconds})); then
          printf 'sendmail-retry: the relay did not take the mail, giving up\n' >&2
          exit "$status"
        fi
        printf 'sendmail-retry: sendmail exited %s, next try in %s s\n' "$status" "$pause" >&2
        sleep "$pause"
        attempt=$((attempt + 1))
        pause=$((pause * 2 > 900 ? 900 : pause * 2))
      done
    '';
  };

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
    # once, so a late delivery still shows the unit as it was when it failed
    text = ''
      unit=$1
      host=$(uname -n)
      status_text=$(systemctl status --full --no-pager --lines=50 -- "$unit" || true)
      {
        printf 'To: root\n'
        printf 'Subject: [%s] %s failed\n' "$host" "$unit"
        printf 'MIME-Version: 1.0\n'
        printf 'Content-Type: text/plain; charset=UTF-8\n'
        printf 'Content-Transfer-Encoding: 8bit\n'
        printf '\n'
        printf '%s\n' "$status_text"
      } | ${lib.getExe sendmailRetry} -i -t
    '';
  };

  # smartd runs its mailer and waits for it, so a mailer that retried in place would stop the
  # watch of every disk while the relay is down. This one hands the mail to a transient unit
  # and returns at once. The unit is lost on a reboot, as an alert-mail@ that still waits is
  smartdMailer = pkgs.writeShellApplication {
    name = "smartd-mailer";
    runtimeInputs = [
      pkgs.coreutils
      config.systemd.package
    ];
    text = ''
      systemd-run --quiet --no-block --collect \
        --description="Mail a smartd alert" \
        --property=StandardInputData="$(base64 -w0)" \
        -- ${lib.getExe sendmailRetry} "$@"
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

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${lib.getExe composeAlert} %i";
        # The script stops retrying on its own; the timeout only catches a sendmail that hangs
        # past that point
        TimeoutStartSec = retrySeconds + 300;
      };
    };

    services.smartd.notifications.mail.mailer = lib.getExe smartdMailer;
  };
}
