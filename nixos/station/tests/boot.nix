{ pkgs, inputs, ... }:

# The station booted in a VM beside a router and the PC, on demand and not in the flake's
# checks: `nix build .#station-boot-test -L`. The station runs its own module list. Only what a
# VM cannot have is replaced: the disk layout, the card's MAC, smartd, and the secrets
let
  station = inputs.self.nixosConfigurations.nixos-station;
  inherit (pkgs) lib;
  backup = station.config.fileSystems."/srv/backup";

  # The driver numbers the nodes in name order, and each card's MAC carries that number
  pcMac = "52:54:00:12:01:01";
  stationMac = "52:54:00:12:01:03";

  fixtures = import ./fixtures.nix { inherit pkgs pcMac; };

  lanNode = address: {
    virtualisation.vlans = [ 1 ];
    networking.interfaces.eth1.ipv4.addresses = lib.mkForce [
      {
        inherit address;
        prefixLength = 24;
      }
    ];
  };
in
pkgs.testers.runNixOSTest {
  name = "station-boot";

  imports = [
    (import ./test-meta.nix {
      inherit lib;
      description = "Boot nixos-station in a VM and check its network, backups, secrets and alerts";
    })
  ];

  # The station brings its own nixpkgs config and overlays, as outside the test
  node.specialArgs = station._module.specialArgs;
  node.pkgs = lib.mkForce null;
  node.pkgsReadOnly = false;

  nodes.station = {
    imports = station._module.args.modules ++ [
      (import ./fixture-host.nix { inherit fixtures stationMac; })
      (_: {
        virtualisation = {
          vlans = [ 1 ];
          memorySize = 3072;
          cores = 2;
          emptyDiskImages = [ 2048 ];
          # The VM mounts its own disks in place of disko's. The backup volume is the empty
          # disk, with the file system and the options the host declares
          fileSystems."/srv/backup" = {
            device = "/dev/vdb";
            inherit (backup) fsType options;
            autoFormat = true;
          };
        };

        # sops-nix refuses a key in the store, so activation copies it to the host's path
        # before sops-nix reads it; the installer does the same with the real key
        system.activationScripts.testAgeKey.text = ''
          install -D -m 0400 ${fixtures}/key.txt /var/lib/sops-nix/key.txt
        '';
        system.activationScripts.setupSecretsForUsers.deps = [ "testAgeKey" ];
        system.activationScripts.setupSecrets.deps = [ "testAgeKey" ];
      })
    ];
  };

  nodes.router = {
    imports = [ (lanNode "192.168.0.1") ];
    services.dnsmasq = {
      enable = true;
      settings = {
        address = "/probe.test/10.9.8.7";
        no-resolv = true;
      };
    };
    # The SMTP relay and the mailbox in one: every mail stays here, readable over its API
    services.mailpit.instances.trap = {
      listen = "0.0.0.0:8025";
      smtp = "0.0.0.0:1025";
    };
    networking.firewall.allowedTCPPorts = [
      53
      1025
    ];
    networking.firewall.allowedUDPPorts = [ 53 ];
  };

  nodes.pc = {
    imports = [ (lanNode "192.168.0.102") ];
    environment.systemPackages = with pkgs; [ tcpdump ];
  };

  testScript = ''
    from datetime import timedelta

    map_logical = "${pkgs.btrfs-progs}/bin/btrfs-map-logical"
    filefrag = "${pkgs.e2fsprogs}/bin/filefrag"
    scrub = "btrfs-scrub@srv-backup.service"
    scrub_subject = "[nixos-station] " + scrub + " failed"

    def mails():
        return router.succeed("curl -s http://127.0.0.1:8025/api/v1/messages")

    # Starts a unit that returns at once and waits for its end; its Result is the verdict
    def run_to_end(unit):
        station.succeed(f"systemctl start {unit}")
        station.wait_until_succeeds(
            f"case $(systemctl show -P ActiveState {unit}) in active|activating) exit 1;; esac",
            timeout=timedelta(minutes=2),
        )
        return station.succeed(f"systemctl show -P Result {unit}").strip()

    start_all()
    router.wait_for_unit("dnsmasq.service")
    router.wait_for_open_port(1025)
    pc.wait_for_unit("multi-user.target")

    station.wait_for_unit("multi-user.target")
    station.wait_for_unit("systemd-networkd-wait-online.service")

    with subtest("the wired link is configured by its MAC and carries the static address"):
        station.succeed("networkctl status -n0 eth1 | grep -q 'Network File: /etc/systemd/network/10-lan.network'")
        station.succeed("networkctl status -n0 eth1 | grep -q 'State: routable (configured)'")
        station.succeed("ip -4 addr show eth1 | grep -q '192.168.0.104/24'")
        station.succeed("ip route | grep -q 'default via 192.168.0.1'")

    with subtest("skvpn has no profile and its guard is up"):
        station.wait_until_succeeds("systemctl is-active skvpn-guard.service", timeout=timedelta(minutes=2))
        station.wait_until_succeeds("ip link show skvpn-tun", timeout=timedelta(minutes=1))

    with subtest("DNS resolves through the router with the guard up"):
        station.wait_until_succeeds("getent hosts probe.test | grep -q 10.9.8.7", timeout=timedelta(minutes=1))

    with subtest("the LAN is reachable with the guard up"):
        station.succeed("ping -c1 -W5 192.168.0.1")
        station.succeed("ping -c1 -W5 192.168.0.102")
        pc.succeed("ping -c1 -W5 192.168.0.104")

    with subtest("the restic server listens, and the LAN cannot reach it"):
        station.wait_for_unit("srv-backup.mount")
        station.wait_for_unit("restic-rest-server.socket")
        station.succeed("curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8000/ | grep -q 401")
        pc.fail("curl -s --max-time 5 http://192.168.0.104:8000/")

    with subtest("the password comes from sops before the users exist"):
        station.succeed("test -s /run/secrets-for-users/rokokol-password-hash")
        station.succeed("getent shadow rokokol | cut -d: -f2 | grep -q '^\\$6\\$'")

    with subtest("wake-pc reaches the PC as a broadcast on the LAN, past the TUN"):
        pc.succeed("tcpdump -i eth1 -n -c1 -w /tmp/wol.pcap 'udp port 9' >/tmp/tcpdump.log 2>&1 &")
        pc.wait_until_succeeds("grep -q 'listening on eth1' /tmp/tcpdump.log", timeout=timedelta(seconds=30))
        station.succeed("su - rokokol -c wake-pc")
        pc.wait_until_succeeds(
            "test -s /tmp/wol.pcap && tcpdump -n -r /tmp/wol.pcap | grep -q '192.168.0.104.* > 192.168.0.255.9'",
            timeout=timedelta(seconds=30),
        )
        station.fail("su - nobody -s /bin/sh -c 'cat /run/secrets/pc-mac'")

    with subtest("the LAN broadcast address is bound to the wired link before any TUN rule"):
        station.succeed("ip route get 192.168.0.255 | grep -q 'broadcast 192.168.0.255 dev eth1 table local'")

    with subtest("a failed heartbeat mails root through the relay"):
        station.fail("systemctl start backup-heartbeat.service")
        router.wait_until_succeeds(
            "curl -s http://127.0.0.1:8025/api/v1/messages | grep -qF '[nixos-station] backup-heartbeat.service failed'",
            timeout=timedelta(minutes=1),
        )
        assert "failed (attempt" not in mails(), "a mail sent at the first try names an attempt"
        station.succeed("systemctl reset-failed backup-heartbeat.service")

    with subtest("an alert waits for a relay that is down and arrives once it is up"):
        alert = "alert-mail@backup-heartbeat.service.service"
        # The mail of the subtest above would match the search below on its own
        router.succeed("curl -sf -X DELETE http://127.0.0.1:8025/api/v1/messages")
        assert "backup-heartbeat" not in mails(), "the mailbox kept the earlier alert"
        router.succeed("systemctl stop mailpit-trap.service")
        station.fail("systemctl start backup-heartbeat.service")
        station.wait_until_succeeds(f"journalctl -u {alert} | grep -qF 'next try in'", timeout=timedelta(minutes=1))
        state = station.succeed(f"systemctl show -P ActiveState {alert}").strip()
        assert state == "activating", f"{alert} gave up while the relay was down: {state}"
        router.succeed("systemctl start mailpit-trap.service")
        router.wait_for_open_port(1025)
        # The subject says which try got through and how late the alert is
        router.wait_until_succeeds(
            "curl -s http://127.0.0.1:8025/api/v1/messages"
            " | grep -qE '\\[nixos-station\\] backup-heartbeat.service failed \\(attempt [2-9], [0-9]+ min late\\)'",
            timeout=timedelta(minutes=3),
        )
        station.wait_until_succeeds(f"test $(systemctl show -P ActiveState {alert}) = inactive", timeout=timedelta(minutes=1))
        result = station.succeed(f"systemctl show -P Result {alert}").strip()
        assert result == "success", f"{alert} ended with {result}"
        station.succeed("systemctl reset-failed backup-heartbeat.service")

    with subtest("the backup volume is btrfs, mounted with the host's options"):
        station.succeed("findmnt -no FSTYPE /srv/backup | grep -qx btrfs")
        station.succeed("findmnt -no OPTIONS /srv/backup | tr , '\\n' | grep -qx noatime")

    with subtest("a scrub of the backup volume runs through its unit and passes"):
        station.succeed(f"systemctl show -P OnFailure {scrub} | grep -qx 'alert-mail@{scrub}.service'")
        result = run_to_end(scrub)
        assert result == "success", f"{scrub} ended with {result}"
        station.succeed(f"journalctl -u {scrub} | grep -q 'scrub done for'")
        # systemd queues the alert with the scrub's own state change, so by now it would be a
        # job or would have left the inactive state; the mailbox alone could still be empty
        alert = f"alert-mail@{scrub}.service"
        station.fail(f"systemctl list-jobs --no-legend | grep -qF '{alert}'")
        station.succeed(f"test \"$(systemctl show -P InactiveExitTimestampMonotonic '{alert}')\" = 0")
        assert scrub_subject not in mails(), "a passing scrub sent an alert"

    with subtest("a scrub that finds a rotten block fails and mails root"):
        # Random data, so that nothing compresses it or keeps it inline in the metadata
        station.succeed("dd if=/dev/urandom of=/srv/backup/rot bs=1M count=8 status=none && sync")
        block = station.succeed(filefrag + " -v /srv/backup/rot | awk '$1 == \"0:\" { print $4 }' | tr -d .").strip()
        device = station.succeed("findmnt -no SOURCE /srv/backup").strip()
        # btrfs addresses data by its own logical offsets; this maps one to the disk's offset.
        # It exits 0 when it finds nothing, so the number is checked
        physical = station.succeed(
            f"{map_logical} -l $(({block} * 4096)) {device} | awk '$1 == \"mirror\" {{ print $6; exit }}'"
        ).strip()
        assert physical.isdigit(), f"no disk offset for logical block {block}: {physical!r}"
        station.succeed(
            f"dd if=/dev/urandom of={device} bs=4096 seek=$(({physical} / 4096)) count=16 conv=notrunc oflag=direct status=none"
        )
        result = run_to_end(scrub)
        assert result != "success", f"{scrub} passed over a rotten block"
        router.wait_until_succeeds(
            "curl -s http://127.0.0.1:8025/api/v1/messages | grep -qF '" + scrub_subject + "'",
            timeout=timedelta(minutes=1),
        )
        station.succeed(f"systemctl reset-failed {scrub}")

    with subtest("no unit is failed"):
        station.succeed("test -z \"$(systemctl list-units --failed --no-legend --all)\"")
  '';
}
