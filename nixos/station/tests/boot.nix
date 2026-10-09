{ pkgs, inputs, ... }:

# The station booted in a VM beside a router and the PC, on demand and not in the flake's
# checks: `nix build .#station-boot-test -L`. The station runs its own module list. Only what a
# VM cannot have is replaced: the disk layout, the card's MAC, smartd, and the secrets
let
  station = inputs.self.nixosConfigurations.nixos-station;
  inherit (pkgs) lib;
  backup = station.config.fileSystems."/srv/backup";

  forgejo = {
    inherit (station.config.rokokol.tailnet-web.sites.forgejo) port;
    backendPort = station.config.services.forgejo.settings.server.HTTP_PORT;
    cli = lib.getExe station.config.rokokol.forgejo.cli;
    inherit (station.config.rokokol.forgejo) initialPasswordFile owner;
  };

  # The exporter that the station's Prometheus expects on the PC, as the real PC configures it
  pcNodeExporter = inputs.self.nixosConfigurations.nixos-pc.config.services.prometheus.exporters.node;
  prometheus = "http://127.0.0.1:${toString station.config.services.prometheus.port}";

  grafana = {
    inherit (station.config.rokokol.tailnet-web.sites.grafana) port;
    backendPort = station.config.services.grafana.settings.server.http_port;
    # The admin password of the fixtures
    password = "test";
    datasource =
      (lib.head station.config.services.grafana.provision.datasources.settings.datasources).uid;
    dashboards =
      (lib.head station.config.services.grafana.provision.dashboards.settings.providers).options.path;
  };

  # The driver numbers the nodes in name order, and each card's MAC carries that number
  pcMac = "52:54:00:12:01:01";
  stationMac = "52:54:00:12:01:03";

  fixtures = import ./fixtures.nix {
    inherit pkgs pcMac;
    githubToken = lib.head github.tokens;
  };

  # Two sites on one backend, one of them also open to the LAN, and the page the backend serves
  probe = {
    port = 8090;
    lanPort = 8092;
    backendPort = 8091;
    page = pkgs.writeTextDir "index.html" "tailnet-web probe\n";
  };

  # GitHub on the router: an own public and private repository, the forks the station names,
  # and one fork it does not. The fixtures give the station the first token
  github = rec {
    port = 8080;
    url = "http://192.168.0.1:${toString port}";
    tokens = [
      "token-one"
      "token-two"
    ];
    repos = [
      {
        name = "public-tool";
        private = false;
        fork = false;
      }
      {
        name = "secret-notes";
        private = true;
        fork = false;
      }
      {
        name = "stray-fork";
        private = false;
        fork = true;
      }
    ]
    ++ map (name: {
      inherit name;
      private = false;
      fork = true;
    }) forks
    ++ map (name: {
      inherit name;
      private = true;
      fork = false;
    }) exclude;
    # A repository whose git data the router holds back, as a clone that fails would
    late = "late-tool";
    inherit (station.config.rokokol.forgejo-mirrors) forks exclude;
    mirrored = lib.filter (
      repo: (!repo.fork || lib.elem repo.name forks) && !lib.elem repo.name exclude
    ) repos;
  };

  # What a CI job runs in: a shell, the core tools and ip, which tries the privileged path
  ciImage = pkgs.dockerTools.buildImage {
    name = "huix-ci";
    tag = "test";
    copyToRoot = pkgs.buildEnv {
      name = "huix-ci-root";
      paths = with pkgs; [
        bashInteractive
        coreutils
        iproute2
      ];
      pathsToLink = [ "/bin" ];
    };
    config.Env = [ "PATH=/bin" ];
  };

  # One job that only has to run, and one that asks for the host's root, the Docker socket and
  # privileged mode, and passes only if it got none of them
  workflows = {
    "plain.yml" = ''
      on: [push]
      jobs:
        plain:
          runs-on: ci
          steps:
            - run: echo the job ran
    '';
    "hostile.yml" = ''
      on: [push]
      jobs:
        hostile:
          runs-on: ci
          container:
            image: ${ciImage.imageName}:${ciImage.imageTag}
            options: --privileged --pid=host --network=host -v /:/host
            volumes:
              - /:/hostroot
          steps:
            - run: |
                if [ -e /host/etc/NIXOS ] || [ -e /hostroot/etc/NIXOS ]; then
                  echo "the job reached the host's root"; exit 1
                fi
                if [ -S /var/run/docker.sock ]; then
                  echo "the job got the Docker socket"; exit 1
                fi
                if ip link add probe0 type dummy 2>/dev/null; then
                  echo "the job could change the network, so it was privileged"; exit 1
                fi
    '';
  };

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

        # Both kinds of site, on a backend that does nothing else, so a failure is the module's
        rokokol.tailnet-web.sites = {
          probe = {
            inherit (probe) port;
            backend = "http://127.0.0.1:${toString probe.backendPort}";
          };
          probe-lan = {
            port = probe.lanPort;
            backend = "http://127.0.0.1:${toString probe.backendPort}";
            lan = true;
          };
        };
        systemd.services.tailnet-web-probe = {
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            DynamicUser = true;
            ExecStart = "${lib.getExe pkgs.python3} -m http.server --bind 127.0.0.1 --directory ${probe.page} ${toString probe.backendPort}";
          };
        };

        # The mirrors read the GitHub on the router, which is a private address that Forgejo
        # refuses to migrate from by default. A small page makes the list take several pages
        rokokol.forgejo-mirrors.githubApi = github.url;
        services.forgejo.settings.migrations.ALLOW_LOCALNETWORKS = true;
        systemd.services.forgejo-mirrors.environment.GITHUB_PER_PAGE = "2";

        # Prometheus finds the PC by its tailnet name, which here leads over the LAN
        networking.hosts."192.168.0.102" = [ "nixos-pc" ];
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
      github.port
    ];
    networking.firewall.allowedUDPPorts = [ 53 ];

    # Each repository is one commit whose README holds its name, served as dumb HTTP
    systemd.services.fake-github = {
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [ git ];
      preStart = ''
        mkdir -p state git held
        printf '%s\n' ${lib.head github.tokens} >state/token
        cp ${pkgs.writeText "repos.json" (builtins.toJSON github.repos)} state/repos.json
        chmod u+w state/repos.json
        for name in ${lib.concatMapStringsSep " " (repo: repo.name) github.repos} ${github.late}; do
          work=$(mktemp -d)
          git -C "$work" init -q -b main
          printf '%s\n' "$name" >"$work/README"
          git -C "$work" add README
          git -C "$work" -c user.name=test -c user.email=test@test commit -q -m "first $name"
          git clone -q --bare "$work" "git/$name.git"
          git -C "git/$name.git" update-server-info
        done
        mv git/${github.late}.git held/
      '';
      serviceConfig = {
        StateDirectory = "fake-github";
        WorkingDirectory = "/var/lib/fake-github";
        ExecStart = "${lib.getExe pkgs.python3} ${./fake-github.py} state /var/lib/fake-github/git ${github.url} ${toString github.port}";
      };
    };
  };

  # The PC runs the runner module the real one runs, against the station's Forgejo over the LAN,
  # with the jobs in a local image, since the VM has no registry to pull from
  nodes.pc = {
    imports = [
      (lanNode "192.168.0.102")
      inputs.sops-nix.nixosModules.sops
      ../../services/utils/forgejo-runner.nix
      ../../services/system/node-exporter.nix
    ];
    _module.args.inputs = inputs;
    # The tailnet trusts the exporter's port on the real PC; this one has only the LAN
    networking.firewall.allowedTCPPorts = [ pcNodeExporter.port ];
    environment.systemPackages = with pkgs; [ tcpdump ];
    virtualisation = {
      memorySize = 2048;
      diskSize = 4096;
      docker.enable = true;
    };

    sops.age.keyFile = "/var/lib/sops-nix/key.txt";
    system.activationScripts.testAgeKey.text = ''
      install -D -m 0400 ${fixtures}/key.txt /var/lib/sops-nix/key.txt
    '';
    system.activationScripts.setupSecrets.deps = [ "testAgeKey" ];

    rokokol.forgejo-runner = {
      enable = true;
      name = "nixos-pc";
      url = "http://192.168.0.104:${toString forgejo.port}/";
      labels = [ "ci:docker://${ciImage.imageName}:${ciImage.imageTag}" ];
      secretsFile = "${fixtures}/station.yaml";
    };
  };

  testScript = ''
    import base64
    import json
    import shlex
    import time
    from datetime import timedelta

    map_logical = "${pkgs.btrfs-progs}/bin/btrfs-map-logical"
    filefrag = "${pkgs.e2fsprogs}/bin/filefrag"
    scrub = "btrfs-scrub@srv-backup.service"
    scrub_subject = "[nixos-station] " + scrub + " failed"

    def mails():
        return router.succeed("curl -s http://127.0.0.1:8025/api/v1/messages")

    # Runs a unit to its end; its Result is the verdict. The start waits for the job and fails
    # with the unit, so its own status is left aside. reset-failed clears the start limit, which
    # a test that runs one unit many times in a row would hit
    def run_to_end(unit):
        station.succeed(f"systemctl reset-failed {unit}")
        station.execute(f"systemctl start {unit}")
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

    with subtest("the wired link is named by its MAC, configured by it, and carries the static address"):
        station.succeed("networkctl status -n0 lan | grep -q 'Link File: /etc/systemd/network/10-lan.link'")
        station.succeed("networkctl status -n0 lan | grep -q 'Network File: /etc/systemd/network/10-lan.network'")
        station.succeed("networkctl status -n0 lan | grep -q 'State: routable (configured)'")
        station.succeed("ip -4 addr show lan | grep -q '192.168.0.104/24'")
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

    # The value of each series of a query, by the host it came from
    def promql(query):
        answer = station.succeed(f"curl -sf --get --data-urlencode 'query={query}' ${prometheus}/api/v1/query")
        return {r["metric"].get("host"): float(r["value"][1]) for r in json.loads(answer)["data"]["result"]}

    def wait_for_series(query, wanted):
        deadline = time.monotonic() + 180
        while (found := promql(query)) != wanted:
            assert time.monotonic() < deadline, f"{query} gives {found}, not {wanted}"
            time.sleep(5)

    with subtest("Prometheus scrapes each host by name, and a host that is down shows as down"):
        station.wait_for_unit("prometheus.service")
        pc.wait_for_unit("prometheus-node-exporter.service")
        # The laptop has no VM here, so it stands for a host that is off
        wait_for_series('up{job="node"}', {"nixos-station": 1.0, "nixos-pc": 1.0, "nixos-laptop": 0.0})
        listeners = station.succeed("ss -Hltn 'sport = :${toString station.config.services.prometheus.port}' | awk '{ print $4 }'").split()
        assert listeners == ["${prometheus}".removeprefix("http://")], f"Prometheus listens on {listeners}"

    with subtest("an exporter runs where the thing it measures does, and nowhere else"):
        # smartd is off in the VM, so its exporter is too, and Prometheus does not ask the station
        station.fail("systemctl cat prometheus-smartctl-exporter.service")
        # The PC here runs node_exporter alone, so its other targets are down, as the laptop's
        wait_for_series('up{job="smartctl"}', {"nixos-pc": 0.0, "nixos-laptop": 0.0})
        wait_for_series('up{job="nvidia-gpu"}', {"nixos-pc": 0.0})

    with subtest("the station reports the RAM zram takes and the swap traffic"):
        wait_for_series('count by (host) (zram_memory_used_bytes)', {"nixos-station": 1.0})
        assert "nixos-station" in promql("node_vmstat_pswpin"), "no swap-in counter of the station"
        # The timer runs twice a minute and must not say so in the journal
        station.succeed("test -s ${station.config.rokokol.node-exporter.textfileDir}/zram.prom")
        quiet = station.succeed("journalctl -u zram-metrics.service -o cat").strip()
        assert quiet == "", f"zram-metrics writes to the journal:\n{quiet}"

    with subtest("the LAN cannot reach an exporter"):
        pc.fail("curl -s --max-time 5 -o /dev/null http://192.168.0.104:${toString pcNodeExporter.port}/metrics")

    with subtest("a site answers the tailnet ranges, and nginx refuses every other address"):
        station.wait_for_unit("nginx.service")
        station.wait_for_unit("tailnet-web-probe.service")
        station.wait_for_open_port(${toString probe.backendPort})
        # The VM has no tailnet, so a dummy link carries one address of each Tailscale range.
        # A connection to it runs over loopback, which the firewall lets in, so nginx alone judges
        station.succeed(
            "ip link add tailnet-probe type dummy && ip link set tailnet-probe up"
            " && ip addr add 100.64.0.1/32 dev tailnet-probe"
            " && ip addr add fd7a:115c:a1e0::1/128 dev tailnet-probe nodad"
        )
        for address in ["100.64.0.1", "[fd7a:115c:a1e0::1]"]:
            page = station.succeed(f"curl -sf --interface {address.strip('[]')} http://{address}:${toString probe.port}/")
            assert page == "tailnet-web probe\n", f"the site at {address} served {page!r}"
        for address in ["127.0.0.1", "[::1]", "192.168.0.104"]:
            code = station.succeed(f"curl -s -o /dev/null -w '%{{http_code}}' http://{address}:${toString probe.port}/")
            assert code == "403", f"nginx answered {code} to {address}, outside the tailnet"
        # The firewall keeps the LAN from the port at all: a 403 would make curl exit 0
        pc.fail("curl -s --max-time 5 -o /dev/null http://192.168.0.104:${toString probe.port}/")

    with subtest("a site open to the LAN answers the LAN and the tailnet, and nobody else"):
        page = pc.succeed("curl -sf --max-time 5 http://192.168.0.104:${toString probe.lanPort}/")
        assert page == "tailnet-web probe\n", f"the LAN site served {page!r} to the PC"
        station.succeed("curl -sf --interface 100.64.0.1 http://100.64.0.1:${toString probe.lanPort}/")
        code = station.succeed("curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:${toString probe.lanPort}/")
        assert code == "403", f"nginx answered {code} to loopback on the LAN site"

    with subtest("Grafana shows Prometheus to anyone on the tailnet or the LAN, and only the admin may change it"):
        station.wait_for_unit("grafana.service")
        station.wait_for_open_port(${toString grafana.backendPort})
        listeners = station.succeed("ss -Hltn 'sport = :${toString grafana.backendPort}' | awk '{ print $4 }'").split()
        assert listeners == ["127.0.0.1:${toString grafana.backendPort}"], f"Grafana listens on {listeners}"
        # Its plugins come from the store, so it never tries grafana.com for them
        station.fail("journalctl -u grafana.service -o cat | grep -q 'Installing plugin'")
        query = json.dumps({
            "queries": [{"refId": "A", "datasource": {"uid": "${grafana.datasource}"}, "expr": "up", "instant": True}],
            "from": "now-5m",
            "to": "now",
        })
        for node, url, extra in [
            (station, "http://100.64.0.1:${toString grafana.port}", "--interface 100.64.0.1"),
            (pc, "http://192.168.0.104:${toString grafana.port}", ""),
        ]:
            # Without a login, as a viewer: the data comes through, the admin pages do not
            answer = node.succeed(
                f"curl -s {extra} -w '\\n%{{http_code}}' -H 'Content-Type: application/json' -d '{query}' {url}/api/ds/query"
            )
            body, code = answer.rsplit("\n", 1)
            assert code == "200", f"a viewer at {url} got {code} from a query: {body}"
            frames = json.loads(body)["results"]["A"]["frames"]
            assert frames, f"Grafana gave no series of up to a viewer at {url}: {body}"
            code = node.succeed(f"curl -s {extra} -o /dev/null -w '%{{http_code}}' {url}/api/admin/settings")
            assert code in ("401", "403"), f"a viewer at {url} got {code} from the admin settings"
            code = node.succeed(
                f"curl -s {extra} -u admin:${grafana.password} -o /dev/null -w '%{{http_code}}' {url}/api/admin/settings"
            )
            assert code == "200", f"the admin got {code} at {url}"
            code = node.succeed(
                f"curl -s {extra} -u admin:wrong -o /dev/null -w '%{{http_code}}' {url}/api/admin/settings"
            )
            # A wrong password falls back to the anonymous viewer, which the admin pages refuse
            assert code in ("401", "403"), f"a wrong admin password got {code} at {url}"

    with subtest("the hosts dashboard is there for a viewer, and each of its queries runs in Prometheus"):
        with open("${grafana.dashboards}/hosts.json") as listing:
            dashboard = json.load(listing)
        code = station.succeed(
            "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:${toString grafana.backendPort}/api/dashboards/uid/"
            + dashboard["uid"]
        )
        assert code == "200", f"a viewer got {code} for the dashboard"
        # The station stands for every host and the PC for every GPU; a VM has no CPU sensor
        # and the PC here no GPU, so those panels may come back empty, but never with an error
        values = {"$host": "nixos-station", "$gpu_host": "nixos-pc", "$__rate_interval": "2m"}
        filled = {"CPU", "Memory", "Swap traffic", "Disks"}
        for panel in (p for p in dashboard["panels"] if p["type"] != "row"):
            for target in panel["targets"]:
                expr = target["expr"]
                for name, value in values.items():
                    expr = expr.replace(name, value)
                # A rate needs two scrapes in its window, which a station just booted may not have
                deadline = time.monotonic() + 180
                while True:
                    answer = station.succeed(f"curl -s --get --data-urlencode {shlex.quote('query=' + expr)} ${prometheus}/api/v1/query")
                    result = json.loads(answer)
                    assert result["status"] == "success", f"{panel['title']}: {expr} failed: {answer}"
                    if panel["title"] not in filled or result["data"]["result"]:
                        break
                    assert time.monotonic() < deadline, f"{panel['title']}: {expr} gave no series"
                    time.sleep(5)

    with subtest("Forgejo listens on loopback alone, and its site serves it to the tailnet and the LAN"):
        station.wait_for_unit("forgejo.service")
        station.wait_for_open_port(${toString forgejo.backendPort})
        listeners = station.succeed("ss -Hltn \"sport = :${toString forgejo.backendPort}\" | awk '{ print $4 }'").split()
        assert listeners == ["127.0.0.1:${toString forgejo.backendPort}"], f"Forgejo listens on {listeners}"
        # Its own SSH server is off, so it holds no socket but the one above
        sockets = station.succeed("ss -Hltnp | grep -c \"pid=$(systemctl show -P MainPID forgejo.service),\" || true").strip()
        assert sockets == "1", f"Forgejo holds {sockets} listening sockets"
        page = station.succeed("curl -sf --interface 100.64.0.1 http://100.64.0.1:${toString forgejo.port}/")
        assert "Forgejo" in page, "the tailnet site does not serve Forgejo"
        page = pc.succeed("curl -sf --max-time 5 http://192.168.0.104:${toString forgejo.port}/")
        assert "Forgejo" in page, "the LAN site does not serve Forgejo"
        # A browser on plain HTTP sends no Sec-Fetch-Site, so Forgejo checks the Origin against
        # the Host it gets, port and all. Creating a repository is one of the checked forms
        for node, origin, extra in [
            (station, "http://100.64.0.1:${toString forgejo.port}", "--interface 100.64.0.1"),
            (pc, "http://192.168.0.104:${toString forgejo.port}", ""),
        ]:
            answer = node.succeed(
                f"curl -s {extra} -o /dev/null -w '%{{http_code}}' -X POST -H 'Origin: {origin}' -d x=y {origin}/repo/create"
            )
            assert answer != "403", f"Forgejo took a form posted from {origin} as cross-origin"

    with subtest("the owner's account exists once, and its first password is Forgejo's alone"):
        admins = "runuser -u forgejo -- ${forgejo.cli} admin user list --admin"
        station.wait_until_succeeds(f"{admins} | grep -qw ${forgejo.owner}", timeout=timedelta(minutes=1))
        assert station.succeed("stat -c '%a %U' ${forgejo.initialPasswordFile}").strip() == "400 forgejo"
        station.fail("su - nobody -s /bin/sh -c 'cat ${forgejo.initialPasswordFile}'")
        # A second run finds the account and creates nothing
        station.succeed("systemctl restart forgejo-owner.service")
        count = station.succeed(f"{admins} | grep -cw ${forgejo.owner}").strip()
        assert count == "1", f"{count} admin accounts named ${forgejo.owner}"

    with subtest("a dump of Forgejo runs through its unit, which mails root if it fails"):
        dump = "forgejo-dump.service"
        station.succeed(f"systemctl show -P OnFailure {dump} | grep -qx 'alert-mail@{dump}.service'")
        result = run_to_end(dump)
        assert result == "success", f"{dump} ended with {result}"
        station.succeed("ls ${station.config.services.forgejo.dump.backupDir}/*.zip")

    mirrors_unit = "forgejo-mirrors.service"
    api = "http://127.0.0.1:${toString forgejo.backendPort}/api/v1"
    api_token = "/var/lib/${station.config.systemd.services.forgejo-mirrors.serviceConfig.StateDirectory}/api-token"
    expected = {r["name"]: r for r in json.loads('${builtins.toJSON github.mirrored}')}

    def forgejo_get(path):
        return station.succeed(f"curl -sf -H \"Authorization: token $(cat {api_token})\" '{api}{path}'")

    def mirrors():
        return {r["name"]: r for r in json.loads(forgejo_get("/user/repos?limit=50"))}

    def readme(name):
        return forgejo_get(f"/repos/${forgejo.owner}/{name}/raw/README")

    def use_github_token(token):
        router.succeed(f"printf '%s\\n' {token} >/var/lib/fake-github/state/token")
        station.succeed(f"printf '%s\\n' {token} >/run/secrets/github-mirror-token")

    with subtest("the mirrors follow GitHub: each own repository and each named fork, private as there"):
        router.wait_for_unit("fake-github.service")
        router.wait_for_open_port(${toString github.port})
        # Forgejo refuses the API to an account that still has to change its first password, so
        # this stands for the owner's first login
        station.succeed("runuser -u forgejo -- ${forgejo.cli} admin user must-change-password --unset ${forgejo.owner}")
        station.succeed(f"systemctl show -P OnFailure {mirrors_unit} | grep -qx 'alert-mail@{mirrors_unit}.service'")
        result = run_to_end(mirrors_unit)
        assert result == "success", f"{mirrors_unit} ended with {result}"
        found = mirrors()
        assert set(found) == set(expected), f"the mirrors are {sorted(found)}, not {sorted(expected)}"
        for name, repo in found.items():
            assert repo["mirror"], f"{name} is not a mirror"
            assert repo["private"] == expected[name]["private"], f"{name} has the wrong visibility"
            # The private one only clones with the token, so its README proves the token got there
            assert readme(name) == f"{name}\n", f"{name} holds the wrong content"

    with subtest("a second run leaves every mirror as it was"):
        before = {name: repo["id"] for name, repo in mirrors().items()}
        assert run_to_end(mirrors_unit) == "success"
        assert {name: repo["id"] for name, repo in mirrors().items()} == before, "a second run made a mirror again"

    with subtest("a new token makes each private mirror again, and leaves the public ones alone"):
        before = {name: repo["id"] for name, repo in mirrors().items()}
        use_github_token("${lib.elemAt github.tokens 1}")
        assert run_to_end(mirrors_unit) == "success"
        after = mirrors()
        assert set(after) == set(expected), f"after the new token the mirrors are {sorted(after)}"
        for name, repo in after.items():
            renewed = repo["id"] != before[name]
            assert renewed == expected[name]["private"], f"{name}: made again {renewed}, private {expected[name]['private']}"
            assert readme(name) == f"{name}\n", f"{name} lost its content"

    with subtest("no GitHub token lies in the clear on the disk of Forgejo or in its dump"):
        # Forgejo encrypts the address of a pull mirror in its database and keeps only a bare one
        # in the git config. The dump is a zip, which hides a string from grep, so it is unpacked
        dump = "forgejo-dump.service"
        assert run_to_end(dump) == "success", f"{dump} failed"
        newest = station.succeed("ls -t ${station.config.services.forgejo.dump.backupDir}/*.zip | head -1").strip()
        for token in json.loads('${builtins.toJSON github.tokens}'):
            station.fail(f"grep -rqaF {token} /var/lib/forgejo")
            station.fail(f"${lib.getExe pkgs.unzip} -p {newest} | grep -qaF {token}")

    with subtest("a swap that a stopped run left halfway is finished by the next run"):
        private = next(name for name, repo in expected.items() if repo["private"])
        body = json.dumps({
            "clone_addr": f"${github.url}/git/{private}.git",
            "repo_name": f"{private}-renewing",
            "repo_owner": "${forgejo.owner}",
            "service": "git",
            "mirror": True,
            "private": True,
            "auth_username": "x-access-token",
            "auth_password": "${lib.elemAt github.tokens 1}",
        })
        station.succeed(
            f"printf '%s' '{body}' | curl -sf -X POST -H \"Authorization: token $(cat {api_token})\""
            f" -H 'Content-Type: application/json' --data-binary @- '{api}/repos/migrate'"
        )
        halfway = mirrors()[f"{private}-renewing"]["id"]
        assert run_to_end(mirrors_unit) == "success"
        after = mirrors()
        assert set(after) == set(expected), f"after the swap the mirrors are {sorted(after)}"
        assert after[private]["id"] == halfway, "the next run did not take the mirror the stopped run made"

    with subtest("a mirror whose repository left GitHub is kept"):
        gone = next(name for name, repo in expected.items() if not repo["private"] and not repo["fork"])
        left = json.dumps([r for r in json.loads('${builtins.toJSON github.repos}') if r["name"] != gone])
        router.succeed(f"printf '%s' '{left}' >/var/lib/fake-github/state/repos.json")
        assert run_to_end(mirrors_unit) == "success"
        assert gone in mirrors(), f"{gone} left Forgejo with GitHub"

    with subtest("a mirror whose first clone failed is made again once GitHub serves the data"):
        # A failed migration leaves an empty mirror behind, which looks like a finished one
        listed = json.loads(router.succeed("cat /var/lib/fake-github/state/repos.json"))
        listed.append({"name": "${github.late}", "private": False, "fork": False})
        router.succeed(f"printf '%s' '{json.dumps(listed)}' >/var/lib/fake-github/state/repos.json")
        last_run = f"journalctl -u {mirrors_unit} -o cat -n 8"
        assert run_to_end(mirrors_unit) == "exit-code", station.succeed(last_run)
        router.succeed("mv /var/lib/fake-github/held/${github.late}.git /var/lib/fake-github/git/")
        assert run_to_end(mirrors_unit) == "success", station.succeed(last_run)
        assert readme("${github.late}") == "${github.late}\n", "the failed mirror stayed empty"

    with subtest("a token that GitHub refuses fails the run, which mails root"):
        router.succeed("curl -sf -X DELETE http://127.0.0.1:8025/api/v1/messages")
        router.succeed("printf '%s\\n' refused-token >/var/lib/fake-github/state/token")
        assert run_to_end(mirrors_unit) == "exit-code", f"{mirrors_unit} did not fail on a refused token"
        router.wait_until_succeeds(
            f"curl -s http://127.0.0.1:8025/api/v1/messages | grep -qF '[nixos-station] {mirrors_unit} failed'",
            timeout=timedelta(minutes=1),
        )
        station.succeed(f"systemctl reset-failed {mirrors_unit}")

    def forgejo_send(method, path, body):
        return station.succeed(
            f"printf '%s' '{json.dumps(body)}' | curl -sf -X {method} -H \"Authorization: token $(cat {api_token})\""
            f" -H 'Content-Type: application/json' --data-binary @- '{api}{path}'"
        )

    with subtest("the PC's runner registers, and runs CI jobs in Docker that cannot reach the host"):
        pc.wait_for_unit("docker.service")
        pc.succeed("docker load <${ciImage}")
        station.wait_for_unit("forgejo-runners.service")
        # The nixpkgs module escapes the unit's name as a path, so a pattern finds the one runner
        runner_log = "journalctl -u 'forgejo-runner-*' -o cat"
        try:
            pc.wait_until_succeeds(
                f"{runner_log} | grep -q 'declared successfully'", timeout=timedelta(minutes=2)
            )
        except Exception:
            print(pc.execute(f"{runner_log} -n 40")[1])
            print(station.execute("journalctl -u forgejo-runners -o cat -n 20")[1])
            raise
        repo = "/repos/${forgejo.owner}/ci-probe"
        forgejo_send("POST", "/user/repos", {"name": "ci-probe", "private": True, "auto_init": True})
        forgejo_send("PATCH", repo, {"has_actions": True})
        with open("${pkgs.writeText "workflows.json" (builtins.toJSON workflows)}") as listing:
            workflows = json.load(listing)
        files = [
            {
                "operation": "create",
                "path": f".forgejo/workflows/{name}",
                "content": base64.b64encode(text.encode()).decode(),
            }
            for name, text in workflows.items()
        ]
        forgejo_send("POST", f"{repo}/contents", {"files": files, "message": "Add the CI probes"})
        deadline = time.monotonic() + 300
        while True:
            runs = json.loads(forgejo_get(f"{repo}/actions/tasks"))["workflow_runs"]
            done = [run for run in runs if run["status"] not in ("waiting", "running", "blocked")]
            if len(done) == len(workflows):
                break
            assert time.monotonic() < deadline, f"the CI runs did not finish: {runs}"
            time.sleep(5)
        failed = [run["name"] for run in done if run["status"] != "success"]
        assert not failed, f"these CI jobs did not pass: {failed}\n" + pc.succeed(f"{runner_log} -n 60")

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
        station.succeed("ip route get 192.168.0.255 | grep -q 'broadcast 192.168.0.255 dev lan table local'")

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
