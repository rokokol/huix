{
  roles,
  panels,
  maxBackupAge,
  minCertificateLife,
  maxDiskUsed,
  maxQuotaUsed,
  resources,
}:

# Mail counters arrive at least every quarter hour. Use windows that hold several samples
let
  inherit (panels)
    query
    panel
    row
    stat
    states
    table
    variable
    ;

  node = ''job="mail", instance=~"$instance"'';

  hourly = metric: by: "sum by (${by}) (increase(${metric}[1h]))";
  daily = metric: by: "sum by (${by}) (increase(${metric}[1d]))";

  deliveries = status: hourly ''mail_deliveries_total{${node}, status="${status}"}'' "instance";
  logins = outcome: hourly ''mail_logins_total{${node}, outcome="${outcome}"}'' "instance";
in
panels.dashboard {
  uid = "mail";
  title = "Mail";
  tags = [
    "service"
    "mail"
  ];
  templating.list = [ (variable "instance" ''push_time_seconds{job="mail"}'' "instance") ];
  panels = [
    (row "Mail now" null 0)
    (stat {
      title = "Queue";
      description = "Messages waiting in the mail queue at the latest report";
      x = 0;
      y = 1;
      w = 8;
      unit = "short";
      expr = "mail_queue_messages{${node}}";
      legend = "{{instance}}";
      thresholds = 1;
      decimals = 0;
    })
    (stat {
      title = "Age of the last backup push";
      description = "Time since the mail node last pushed a backup";
      x = 8;
      y = 1;
      w = 8;
      unit = "s";
      expr = "time() - mail_backup_last_push_timestamp_seconds{${node}}";
      legend = "{{instance}}";
      thresholds = maxBackupAge;
    })
    (stat {
      title = "Time since last metrics push";
      description = "The Pushgateway retains the last report even when the mail node stops sending metrics";
      x = 16;
      y = 1;
      w = 8;
      unit = "s";
      expr = "time() - push_time_seconds{${node}}";
      legend = "{{instance}}";
    })
    (table {
      title = "Reported problems";
      description = "Problems reported by the mail node and their identifiers";
      valueName = null;
      x = 0;
      y = 5;
      w = 16;
      expr = "node_problem{${node}}";
      unit = "none";
      labels = [
        "instance"
        "key"
        "summary"
      ];
    })
    (stat {
      title = "Reboot";
      description = "Whether the mail node reports that it needs a reboot";
      x = 16;
      y = 5;
      w = 8;
      unit = "none";
      expr = "mail_reboot_required{${node}}";
      legend = "{{instance}}";
      mappings = {
        "0" = {
          text = "current";
          color = roles.ok;
        };
        "1" = {
          text = "required";
          color = roles.danger;
        };
      };
    })
    (stat {
      title = "Unparsed reports";
      description = "Reports the mail node has not parsed";
      x = 16;
      y = 9;
      w = 8;
      unit = "short";
      expr = "mail_reports_unparsed_total{${node}}";
      legend = "{{instance}}";
      thresholds = 1;
      decimals = 0;
    })
    (table {
      title = "Certificate lifetime left";
      description = "Time until each reported mail certificate expires";
      x = 0;
      y = 13;
      w = 12;
      unit = "s";
      expr = "mail_certificate_expiry_timestamp_seconds{${node}} - time()";
      thresholds = minCertificateLife;
      dangerBelow = true;
      labels = [
        "instance"
        "certificate"
      ];
      valueName = "Time left";
      sortDesc = false;
    })
    (table {
      title = "Mailbox quota used";
      description = "Share of the configured quota used by each mailbox";
      x = 12;
      y = 13;
      w = 12;
      unit = "percentunit";
      expr = "mail_mailbox_quota_used_ratio{${node}}";
      thresholds = maxQuotaUsed;
      labels = [
        "instance"
        "mailbox"
      ];
      valueName = "Used";
      sortDesc = true;
    })
    (row "Flow and spam" null 21)
    (panel {
      title = "Messages accepted per hour";
      description = "Messages accepted during the hour before each bar";
      bars = true;
      interval = "1h";
      x = 0;
      y = 22;
      w = 8;
      unit = "short";
      min = 0;
      queries = [
        (query "A" (hourly "mail_accepted_messages_total{${node}}" "instance") "{{instance}}")
      ];
    })
    (panel {
      title = "Deliveries per hour";
      description = "Delivery attempts by result during the hour before each bar";
      bars = true;
      interval = "1h";
      x = 8;
      y = 22;
      w = 8;
      unit = "short";
      min = 0;
      queries = [
        (query "A" (deliveries "sent") "{{instance}} delivered")
        (query "B" (deliveries "deferred") "{{instance}} deferred")
        (query "C" (deliveries "bounced") "{{instance}} bounced")
      ];
    })
    (panel {
      title = "Queue history";
      description = "Messages waiting in the mail queue at each reported sample";
      bars = true;
      interval = "15m";
      x = 16;
      y = 22;
      w = 8;
      unit = "short";
      min = 0;
      thresholds = 1;
      queries = [ (query "A" "mail_queue_messages{${node}}" "{{instance}}") ];
    })
    (panel {
      title = "rspamd actions per hour";
      description = "Messages scanned by action during the hour before each bar";
      bars = true;
      interval = "1h";
      x = 0;
      y = 30;
      w = 12;
      unit = "short";
      min = 0;
      queries = [
        (query "A" (hourly "mail_scanned_messages_total{${node}}" "instance, action")
          "{{instance}} {{action}}"
        )
      ];
    })
    (panel {
      title = "SMTP rejections per hour";
      description = "SMTP rejections by reason during the hour before each bar";
      bars = true;
      interval = "1h";
      x = 12;
      y = 30;
      w = 12;
      unit = "short";
      min = 0;
      queries = [
        (query "A" (hourly "mail_smtp_rejection_reasons_total{${node}}" "instance, reason")
          "{{instance}} {{reason}}"
        )
      ];
    })
    (panel {
      title = "Logins per hour";
      description = "Login attempts by result during the hour before each bar";
      bars = true;
      interval = "1h";
      x = 0;
      y = 38;
      w = 12;
      unit = "short";
      min = 0;
      queries = [
        (query "A" (logins "succeeded") "{{instance}} succeeded")
        (query "B" (logins "failed") "{{instance}} failed")
      ];
    })
    (panel {
      title = "fail2ban bans per hour";
      description = "Bans by jail during the hour before each bar";
      bars = true;
      interval = "1h";
      x = 12;
      y = 38;
      w = 12;
      unit = "short";
      min = 0;
      queries = [
        (query "A" (hourly "mail_fail2ban_bans_total{${node}}" "instance, jail") "{{instance}} {{jail}}")
      ];
    })
    (row "Report and collector history" null 46)
    (panel {
      title = "Report failures per day";
      description = "Unaligned messages and failed TLS sessions during the day before each bar";
      bars = true;
      interval = "1d";
      x = 0;
      y = 47;
      w = 12;
      unit = "short";
      min = 0;
      softMax = 5;
      # The node reports every unaligned message and every failed session
      thresholds = 1;
      queries = [
        (query "A"
          (daily ''mail_dmarc_messages_total{${node}, alignment="unaligned"}'' "instance, reporter")
          "{{instance}} DMARC unaligned from {{reporter}}"
        )
        (query "B" (daily ''mail_tls_rpt_sessions_total{${node}, result="failed"}'' "instance, reporter")
          "{{instance}} TLS-RPT failed from {{reporter}}"
        )
      ];
    })
    (states {
      title = "The station, as the node sees it";
      description = "Whether the station answered the mail node's connectivity check";
      x = 12;
      y = 47;
      w = 12;
      expr = "mail_station_up{${node}}";
      legend = "{{instance}}";
      mappings = {
        "0" = {
          text = "silent";
          color = roles.danger;
        };
        "1" = {
          text = "answers";
          color = roles.ok;
        };
      };
    })
    (stat {
      title = "Collector last caught up";
      description = "Time since the collector last read all available log entries";
      x = 0;
      y = 55;
      w = 6;
      h = 8;
      unit = "s";
      expr = "time() - mail_collector_caught_up_timestamp_seconds{${node}}";
      legend = "{{instance}}";
    })
    (stat {
      title = "Newest mail log event";
      description = "Age of the newest event read by the collector. A quiet log can make this age large";
      x = 6;
      y = 55;
      w = 6;
      h = 8;
      unit = "s";
      expr = "time() - mail_collector_last_event_timestamp_seconds{${node}}";
      legend = "{{instance}}";
    })
    (panel {
      title = "Collector cursor gaps per day";
      description = "Collector cursor gaps detected during the day before each bar";
      bars = true;
      interval = "1d";
      x = 12;
      y = 55;
      w = 12;
      unit = "short";
      min = 0;
      softMax = 5;
      thresholds = 1;
      queries = [
        (query "A" (daily "mail_collector_cursor_gaps_total{${node}}" "instance") "{{instance}}")
      ];
    })
    (row "Who knocks" null 63)
  ]
  ++ panels.attackers "mail" node 64
  ++ panels.serviceHealth {
    y = 72;
    disk = resources.freshDisk "mail" node;
    cpu = resources.freshCpu "mail" node;
    memory = resources.freshMemory "mail" node;
    thresholds = maxDiskUsed;
    forecast = resources.visualForecast;
  };
}
