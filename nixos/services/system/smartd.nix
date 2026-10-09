{ config, pkgs, ... }:

# SMART monitoring of every disk the host finds at boot, with desktop alerts. smartd polls every
# 30 minutes and starts a scheduled self-test in the first poll inside the matching hour. A test
# whose hour passed while the host slept or was off starts in the first poll after that
{
  services.smartd = {
    enable = true;

    # Keeps the last checked hour across a shutdown, so that the missed test is not lost. The
    # state is a few KiB for each disk, written when a test starts or a counter changes
    extraOptions = [ "--savestates=/var/lib/smartd/" ];

    # -a watches health, attributes and the error and self-test logs. The long test starts at
    # 19:00 on Saturday and Sunday, and the slowest disk needs 85 minutes, so it ends before 21:00.
    # The short test runs at 14:00 each day and at 20:00 on weekdays, away from the long test.
    # -I 194 stops the tracking of the temperature attribute: it changes on most polls and fills
    # the journal with lines that are not alerts. NVMe disks have no such attribute and ignore it
    defaults.monitored = "-a -I 194 -s (L/../../[67]/19|S/../.././14|S/../../[1-5]/20)";

    notifications = {
      # Sends the alert to the desktop notification daemon of the graphical session. A host
      # without one mails the alert, which alert-mail.nix turns on
      systembus-notify.enable = config.rokokol.workstation.enable;

      # systembus-notify alone gets no alerts, see WORKAROUNDS.md
      wall.enable = true;
    };
  };

  # The module sets no state directory, and smartd does not create one
  systemd.services.smartd.serviceConfig.StateDirectory = "smartd";

  # The history of the SMART attributes for the station's Prometheus, where smartd watches the
  # disks; smartd stays the one that alerts. It listens as node-exporter.nix does
  services.prometheus.exporters.smartctl.enable = config.services.smartd.enable;

  # smartctl for a manual look: `sudo smartctl -x /dev/sda`
  environment.systemPackages = with pkgs; [ smartmontools ];
}
