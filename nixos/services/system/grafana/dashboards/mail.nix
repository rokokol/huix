{
  roles,
  panels,
  maxBackupAge,
  minCertificateLife,
  maxDiskUsed,
  maxQuotaUsed,
}:

# The dashboard of the mail node, from what it pushes to the Pushgateway: the mail that flows
# through it and the spam it filters, then its health. The node pushes its counters as totals at
# least every quarter hour, so a flow is the increase over an hour or a day, which holds several
let
  inherit (panels)
    query
    panel
    row
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
    (row "Flow and spam" null 0)
    (panel {
      title = "Deliveries per hour";
      x = 0;
      y = 1;
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
      title = "Messages accepted per hour";
      x = 8;
      y = 1;
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
      title = "Queue";
      x = 16;
      y = 1;
      w = 8;
      unit = "short";
      min = 0;
      # The node reports any message that waits in the queue
      thresholds = 1;
      queries = [ (query "A" roles.series-1 "mail_queue_messages{${node}}" "{{instance}}") ];
    })
    (panel {
      title = "rspamd actions per hour";
      x = 0;
      y = 9;
      w = 8;
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
      title = "Filed into Junk per hour";
      x = 8;
      y = 9;
      w = 8;
      unit = "short";
      min = 0;
      queries = [
        # The action whose header Sieve files into Junk
        (query "A" roles.series-1
          (hourly ''mail_scanned_messages_total{${node}, action="add header"}'' "instance")
          "{{instance}}"
        )
      ];
    })
    (panel {
      title = "SMTP rejections per hour";
      x = 16;
      y = 9;
      w = 8;
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
      y = 17;
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
      y = 17;
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

    (row "Health" null 25)
    (panel {
      title = "Certificate lifetime left";
      x = 0;
      y = 26;
      w = 8;
      unit = "s";
      min = 0;
      shaded = true;
      thresholds = minCertificateLife;
      dangerBelow = true;
      queries = [
        (query "A" roles.series-1 "mail_certificate_expiry_timestamp_seconds{${node}} - time()"
          "{{instance}} {{certificate}}"
        )
      ];
    })
    (panel {
      title = "Disk used";
      x = 8;
      y = 26;
      w = 8;
      unit = "percentunit";
      min = 0;
      max = 1;
      thresholds = maxDiskUsed;
      queries = [ (query "A" roles.series-1 "mail_disk_used_ratio{${node}}" "{{instance}}") ];
    })
    (panel {
      title = "Mailbox quota used";
      x = 16;
      y = 26;
      w = 8;
      unit = "percentunit";
      min = 0;
      max = 1;
      shaded = true;
      thresholds = maxQuotaUsed;
      queries = [
        (query "A" roles.series-1 "mail_mailbox_quota_used_ratio{${node}}" "{{instance}} {{mailbox}}")
      ];
    })
    (panel {
      title = "Report failures per day";
      x = 0;
      y = 34;
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
    (panel {
      title = "Reports that did not parse";
      x = 12;
      y = 34;
      w = 12;
      unit = "short";
      min = 0;
      # The node reports these while any of them stays at the report addresses
      thresholds = 1;
      queries = [ (query "A" roles.series-1 "mail_reports_unparsed_total{${node}}" "{{instance}}") ];
    })
    (panel {
      title = "Age of the last backup push";
      x = 0;
      y = 42;
      w = 8;
      unit = "s";
      min = 0;
      thresholds = maxBackupAge;
      queries = [
        (query "A" roles.series-1 "time() - mail_backup_last_push_timestamp_seconds{${node}}"
          "{{instance}}"
        )
      ];
    })
    (states {
      title = "The station, as the node sees it";
      x = 8;
      y = 42;
      w = 8;
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
      title = "Time since the station answered";
      x = 16;
      y = 42;
      w = 8;
      unit = "s";
      min = 0;
      queries = [
        (query "A" roles.series-1 "time() - mail_station_last_answer_timestamp_seconds{${node}}"
          "{{instance}} answer"
        )
        (query "B" roles.series-3 "time() - mail_station_last_check_timestamp_seconds{${node}}"
          "{{instance}} question"
        )
      ];
    })
    (panel {
      title = "Collector lag";
      x = 0;
      y = 50;
      w = 8;
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
      x = 8;
      y = 50;
      w = 8;
      unit = "short";
      min = 0;
      thresholds = 1;
      queries = [
        (query "A" roles.series-1 (daily "mail_collector_cursor_gaps_total{${node}}" "instance")
          "{{instance}}"
        )
      ];
    })
    (panel {
      title = "Problems the node reports";
      x = 16;
      y = 50;
      w = 8;
      unit = "short";
      min = 0;
      # The station alerts while this is above zero
      thresholds = 1;
      queries = [
        (query "A" roles.series-1 "count by (instance) (node_problem{${node}})" "{{instance}}")
      ];
    })
    (table {
      title = "What the node reports now";
      x = 0;
      y = 58;
      w = 12;
      expr = "node_problem{${node}}";
      unit = "none";
      thresholds = 1;
      labels = [
        "instance"
        "key"
        "summary"
      ];
    })
    (states {
      title = "Reboot";
      x = 12;
      y = 58;
      w = 12;
      expr = "mail_reboot_required{${node}}";
      legend = "{{instance}}";
      mappings = {
        "0" = {
          text = "current";
          color = roles.ok;
        };
        "1" = {
          text = "required";
          color = roles.series-3;
        };
      };
    })
  ];
}
