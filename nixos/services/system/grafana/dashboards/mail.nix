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
  templating.list = [ (variable "instance" ''push_time_seconds{job="mail"}'' "instance") ];
  panels = [
    (row "Mail now" null 0)
    (stat {
      title = "Queue";
      x = 0;
      y = 1;
      w = 6;
      unit = "short";
      expr = "mail_queue_messages{${node}}";
      legend = "{{instance}}";
      thresholds = 1;
      decimals = 0;
    })
    (stat {
      title = "Age of the last backup push";
      x = 6;
      y = 1;
      w = 6;
      unit = "s";
      expr = "time() - mail_backup_last_push_timestamp_seconds{${node}}";
      legend = "{{instance}}";
      thresholds = maxBackupAge;
    })
    (stat {
      title = "Disk used";
      x = 12;
      y = 1;
      w = 6;
      unit = "percentunit";
      expr = resources.freshDisk "mail" node;
      legend = "{{instance}}";
      thresholds = maxDiskUsed;
    })
    (stat {
      title = "Time since last metrics push";
      description = "The Pushgateway retains the last report even when the mail node stops sending metrics";
      x = 18;
      y = 1;
      w = 6;
      unit = "s";
      expr = "time() - push_time_seconds{${node}}";
      legend = "{{instance}}";
    })
    (table {
      title = "Reported problems";
      valueName = "Reported";
      x = 0;
      y = 5;
      w = 16;
      expr = "node_problem{${node}}";
      unit = "none";
      thresholds = 1;
      labels = [
        "instance"
        "key"
        "summary"
      ];
    })
    (stat {
      title = "Reboot";
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
          color = roles.kind-warning;
        };
      };
    })
    (stat {
      title = "Unparsed reports";
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
      x = 0;
      y = 22;
      w = 8;
      unit = "short";
      min = 0;
      queries = [
        (query "A" roles.series-1 (hourly "mail_accepted_messages_total{${node}}" "instance")
          "{{instance}}"
        )
      ];
    })
    (panel {
      title = "Deliveries per hour";
      x = 8;
      y = 22;
      w = 8;
      unit = "short";
      min = 0;
      queries = [
        (query "A" roles.series-1 (deliveries "sent") "{{instance}} delivered")
        (query "B" roles.series-3 (deliveries "deferred") "{{instance}} deferred")
        (query "C" roles.series-4 (deliveries "bounced") "{{instance}} bounced")
      ];
    })
    (panel {
      title = "Queue history";
      x = 16;
      y = 22;
      w = 8;
      unit = "short";
      min = 0;
      thresholds = 1;
      queries = [ (query "A" roles.series-1 "mail_queue_messages{${node}}" "{{instance}}") ];
    })
    (panel {
      title = "rspamd actions per hour";
      x = 0;
      y = 30;
      w = 12;
      unit = "short";
      min = 0;
      shaded = true;
      queries = [
        (query "A" roles.series-1 (hourly "mail_scanned_messages_total{${node}}" "instance, action")
          "{{instance}} {{action}}"
        )
      ];
    })
    (panel {
      title = "SMTP rejections per hour";
      x = 12;
      y = 30;
      w = 12;
      unit = "short";
      min = 0;
      shaded = true;
      queries = [
        (query "A" roles.series-1 (hourly "mail_smtp_rejection_reasons_total{${node}}" "instance, reason")
          "{{instance}} {{reason}}"
        )
      ];
    })
    (panel {
      title = "Logins per hour";
      x = 0;
      y = 38;
      w = 12;
      unit = "short";
      min = 0;
      queries = [
        (query "A" roles.series-1 (logins "succeeded") "{{instance}} succeeded")
        (query "B" roles.series-4 (logins "failed") "{{instance}} failed")
      ];
    })
    (panel {
      title = "fail2ban bans per hour";
      x = 12;
      y = 38;
      w = 12;
      unit = "short";
      min = 0;
      shaded = true;
      queries = [
        (query "A" roles.series-1 (hourly "mail_fail2ban_bans_total{${node}}" "instance, jail")
          "{{instance}} {{jail}}"
        )
      ];
    })
    (row "Report and collector history" null 46)
    (panel {
      title = "Report failures per day";
      x = 0;
      y = 47;
      w = 12;
      unit = "short";
      min = 0;
      # The node reports every unaligned message and every failed session
      thresholds = 1;
      queries = [
        (query "A" roles.series-1
          (daily ''mail_dmarc_messages_total{${node}, alignment="unaligned"}'' "instance, reporter")
          "{{instance}} DMARC unaligned from {{reporter}}"
        )
        (query "B" roles.series-3
          (daily ''mail_tls_rpt_sessions_total{${node}, result="failed"}'' "instance, reporter")
          "{{instance}} TLS-RPT failed from {{reporter}}"
        )
      ];
    })
    (states {
      title = "The station, as the node sees it";
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
    (panel {
      title = "Collector lag";
      x = 0;
      y = 55;
      w = 12;
      unit = "s";
      min = 0;
      queries = [
        (query "A" roles.series-1 "time() - mail_collector_caught_up_timestamp_seconds{${node}}"
          "{{instance}} since caught up"
        )
        (query "B" roles.series-3 "time() - mail_collector_last_event_timestamp_seconds{${node}}"
          "{{instance}} since the newest event"
        )
      ];
    })
    (panel {
      title = "Collector cursor gaps per day";
      x = 12;
      y = 55;
      w = 12;
      unit = "short";
      min = 0;
      thresholds = 1;
      queries = [
        (query "A" roles.series-1 (daily "mail_collector_cursor_gaps_total{${node}}" "instance")
          "{{instance}}"
        )
      ];
    })
    (row "Who knocks" null 63)
  ]
  ++ panels.attackers "mail" node 64
  ++ [
    (row "Capacity" null 72)
    (panel {
      title = "Disk use in seven days";
      description = "Linear forecast from seven days of measurements the node actually made. The red line marks a full disk, and a gap a history too short to forecast";
      x = 0;
      y = 73;
      w = 24;
      unit = "percentunit";
      thresholds = 1;
      queries = [
        (query "A" roles.series-1 (resources.forecast (resources.freshDisk "mail" node)) "{{instance}}")
      ];
    })
  ];
}
