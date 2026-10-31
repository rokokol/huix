{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

# Alerts for a host with no desktop to show a notification on, in two levels. A problem is sent
# once when it opens and once when it closes, by mail and, where it is on, by Telegram and to an
# agent; a daily mail lists what is still open. msmtp becomes the system sendmail, so smartd and
# the alerts reach an SMTP relay through it. The relay and the real recipient are private: both
# arrive through sops and never enter the store
let
  cfg = config.rokokol.alert-mail;
  inherit (cfg) stateDir;

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

  # The registry of open problems, scripts/alert.sh, with its environment. The aliases file maps
  # root to the real address, so the address is not in the store
  alertWith =
    name: extra: command:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = with pkgs; [
        coreutils
        curl
        util-linux
        config.systemd.package
      ];
      text = ''
        export ALERT_STATE=${stateDir}
        export ALERT_MAIL="${lib.getExe sendmailRetry} -i -t"
        export ALERT_TELEGRAM_API=${lib.optionalString cfg.telegram.enable cfg.telegram.api}
        export ALERT_TELEGRAM_TOKEN=${telegramSecret "telegram-bot-token"}
        export ALERT_TELEGRAM_CHAT=${telegramSecret "telegram-owner-chat-id"}
        export ALERT_NOTIFY=${lib.optionalString (cfg.notify != null) cfg.notify}
        export ALERT_METRICS=${config.rokokol.node-exporter.textfileDir}/alerts.prom
        ${extra}
        exec ${lib.getExe pkgs.bash} ${alertScript} ${command}
      '';
    };

  # Sends one message from the outbox, in a transient unit of its own
  alertDeliver = alertWith "alert-deliver" "" ''deliver "$@"'';

  # Each message leaves in a unit of its own, so a mail that waits a day for its relay holds up
  # neither Telegram nor the next alert. The unit is lost on a reboot, and the reconcile hands
  # the message on again
  alert = alertWith "alert" ''
    export ALERT_SPAWN="systemd-run --quiet --no-block --collect --description=Deliver_an_alert ${lib.getExe alertDeliver}"
  '' ''"$@"'';

  alertScript = builtins.path {
    name = "alert";
    path = "${inputs.self}/scripts/alert.sh";
  };

  # Opens the problem of the unit named in $1 with its status and last journal lines. systemctl
  # status exits 3 for a failed unit, and that unit is the reason for the alert. The status is
  # read once, so a late delivery still shows the unit as it was when it failed
  composeAlert = pkgs.writeShellApplication {
    name = "alert-unit";
    runtimeInputs = [ config.systemd.package ];
    text = ''
      status_text=$(systemctl status --full --no-pager --lines=50 -- "$1" || true)
      printf '%s\n' "$status_text" | ${lib.getExe alert} raise "unit:$1" "[$(uname -n)] $1 failed"
    '';
  };

  # Read from /run/secrets by the alert units, which run as root. Not systemd credentials: a
  # unit whose credential is missing does not start at all, so a Telegram secret not yet in
  # sops would stop the mail as well
  telegramSecret = name: lib.optionalString cfg.telegram.enable config.sops.secrets.${name}.path;

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
  options.rokokol.alert-mail = {
    enable = lib.mkEnableOption "alert e-mail through an SMTP relay";

    stateDir = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "/var/lib/alerts";
      description = "Directory of the open problems and their journal";
    };

    telegram = {
      enable = lib.mkEnableOption ''
        a copy of each alert in the owner's Telegram, through the bot whose token and the
        owner's chat id are the sops secrets telegram-bot-token and telegram-owner-chat-id
      '';

      api = lib.mkOption {
        type = lib.types.str;
        default = "https://api.telegram.org";
        description = "Base URL of the Telegram Bot API";
      };
    };

    notify = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Command that takes one line of text as its argument and hands it to an agent";
    };

    digestTime = lib.mkOption {
      type = lib.types.str;
      default = "09:00";
      description = "Time of day of the mail that lists every problem still open";
    };

    sources = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = { };
      example = {
        backup = "/run/backup-heartbeat/causes";
      };
      description = ''
        Files of causes, by source name, each written by a check: one cause a line, a key, a
        tab and a subject. Each cause is a problem of its own under <source>:<key>, opened
        when the file lists it and closed when it no longer does
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        sops.secrets."telegram-bot-token" = lib.mkIf cfg.telegram.enable { };
        sops.secrets."telegram-owner-chat-id" = lib.mkIf cfg.telegram.enable { };

        # Anyone on the host may read what is open and what changed; only root writes it
        environment.systemPackages = [ alert ];
        systemd.tmpfiles.rules = [ "d ${stateDir} 0755 root root -" ];

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

        # OnFailure=alert-mail@%n.service in a unit opens its problem, which is sent once. A failure
        # while the problem is open only updates it, and alert-reconcile closes it once the unit
        # recovers. A unit left inactive by a failed dependency has Result=success but never ran,
        # and alert-reconcile keeps its problem open. While an alert waits for the relay, a new
        # failure of the same unit joins it
        systemd.services."alert-mail@" = {
          description = "Raise an alert that %i failed";

          # A flapping unit raises at most three times an hour, and further starts fail. The
          # retries run inside one start, so they do not count against this limit
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

        # Closes the problem of each unit that recovered, keeps the reboot problem current, and
        # reads every file of causes again, in case a change slipped past its path unit
        systemd.services.alert-reconcile = {
          description = "Close the alerts whose cause is gone";
          script = ''
            ${lib.getExe alert} reconcile
          ''
          + lib.concatStrings (
            lib.mapAttrsToList (name: file: ''
              if [ -e ${lib.escapeShellArg file} ]; then
                ${lib.getExe alert} sync ${name} ${lib.escapeShellArg file}
              fi
            '') cfg.sources
          );
          serviceConfig = {
            Type = "oneshot";
            TimeoutStartSec = retrySeconds + 300;
          };
        };

        systemd.timers.alert-reconcile = {
          wantedBy = [ "timers.target" ];
          timerConfig.OnCalendar = "*:0/5";
        };

        # The second level: a mail with every problem still open, and nothing when all is well
        systemd.services.alert-digest = {
          description = "Mail the alerts still open";
          after = [ "alert-reconcile.service" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStartPre = "${lib.getExe alert} reconcile";
            ExecStart = "${lib.getExe alert} digest";
            TimeoutStartSec = retrySeconds + 300;
          };
        };

        systemd.timers.alert-digest = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = cfg.digestTime;
            # A digest missed while the host was off comes at the next boot
            Persistent = true;
          };
        };

        services.smartd.notifications.mail.mailer = lib.getExe smartdMailer;
      }

      # A check that rewrites its file of causes has them opened and closed at once
      {
        systemd.paths = lib.mapAttrs' (
          name: file:
          lib.nameValuePair "alert-sync-${name}" {
            wantedBy = [ "multi-user.target" ];
            pathConfig.PathChanged = file;
          }
        ) cfg.sources;

        systemd.services = lib.mapAttrs' (
          name: file:
          lib.nameValuePair "alert-sync-${name}" {
            description = "Raise and close the alerts that ${name} lists";
            # The path unit does not start a sync that is still running, so a change made during
            # one would wait for the reconcile; the sync runs again until the file holds still
            script = ''
              while :; do
                seen=$(stat -c '%i %y' ${lib.escapeShellArg file})
                ${lib.getExe alert} sync ${name} ${lib.escapeShellArg file}
                [ "$(stat -c '%i %y' ${lib.escapeShellArg file})" != "$seen" ] || break
              done
            '';
            serviceConfig = {
              Type = "oneshot";
              TimeoutStartSec = retrySeconds + 300;
            };
          }
        ) cfg.sources;
      }
    ]
  );
}
