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

  restic = {
    inherit (station.config.rokokol.restic-server) dataDir snapshotDir;
  };

  radicale = {
    inherit (station.config.rokokol.tailnet-web.sites.radicale) port;
    inherit (station.config.rokokol.radicale) dataDir snapshotDir;
    backend = lib.head station.config.services.radicale.settings.server.hosts;
    # The config on the mounted state, which the agent reads
    mcpConfig = "${agent.home}/.hermes/config.yaml";
  };

  syncthing = {
    inherit (station.config.services.syncthing.settings.folders.myWiki) id path;
    inherit (station.config.services.syncthing) user;
    config = "${station.config.services.syncthing.configDir}/config.xml";
    inherit (station.config.rokokol.syncthing.archive) snapshotDir;
    shared = station.config.services.syncthing.settings.folders.claude-shared.path;
  };

  agent = rec {
    inherit (station.config.rokokol.mya-agent) user;
    inherit (station.config.users.users.${user}) home;
    inherit (station.config.rokokol.mya-agent) notify syncUnit;
    stateDir = "${home}/.hermes";
    workDir = home;
    ownerChatId = "1234567";

    # What the session can reach, typed into it as a command. Each line is a name and yes or no;
    # the report appears whole, once every check has run
    probe = pkgs.writeShellScript "agent-probe" ''
      report=$HOME/probe
      exec 3>"$report.part"
      can() {
        name=$1
        shift
        if "$@" >/dev/null 2>&1; then echo "$name=yes" >&3; else echo "$name=no" >&3; fi
      }
      echo "user=$(id -un)" >&3
      can write-vault sh -c 'echo agent >"$HOME/myWiki/agent.md"'
      can write-shared sh -c 'echo agent >${syncthing.shared}/agent.md'
      can read-shared test -r ${syncthing.shared}/settings.json
      can owner-home test -e /home/rokokol/.owner-only
      can snapshots ls ${syncthing.snapshotDir}
      can restic ls ${station.config.rokokol.restic-server.dataDir}
      can syncthing-key cat ${syncthing.config}
      # Syncthing runs as the same user, so its view of the files is the next way to its key
      can syncthing-root ls "/proc/$1/root${station.config.services.syncthing.configDir}"
      can user-manager-root test -r "/proc/$2/root${syncthing.shared}/settings.json"
      can user-manager-spawn env \
        XDG_RUNTIME_DIR="/proc/$2/root/run/user/$(id -u)" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/proc/$2/root/run/user/$(id -u)/bus" \
        systemd-run --user --quiet --wait --pipe cat ${syncthing.shared}/settings.json
      can bot-token-env test -n "''${TELEGRAM_BOT_TOKEN:-}"
      can external-skills sh -c 'touch ${lib.head station.config.services.hermes-agent.settings.skills.external_dirs}/writable'
      can sops-key test -r /var/lib/sops-nix/key.txt
      can wake-pc command -v wake-pc
      can pc-mac test -r ${station.config.sops.secrets.pc-mac.path}
      # A setuid program such as sudo could raise the session's privileges
      can new-privileges grep -q '^NoNewPrivs:[[:space:]]*0$' /proc/self/status
      exec 3>&-
      mv "$report.part" "$report"
    '';
  };

  # The driver numbers the nodes in name order, and each card's MAC carries that number
  pcMac = "52:54:00:12:01:01";
  stationMac = "52:54:00:12:01:03";

  # The Bot API stand-in on the router, which the station sends its alerts to
  telegramPort = 8088;

  fixtures = import ./fixtures.nix {
    inherit pkgs pcMac;
    githubToken = lib.head github.tokens;
    telegramOwner = agent.ownerChatId;
  };

  # Two sites on one backend, one of them also open to the LAN, and the page the backend serves
  probe = {
    port = 8090;
    lanPort = 8092;
    backendPort = 8091;
    page = pkgs.writeTextDir "index.html" "tailnet-web probe\n";
  };

  # Stands in for the GitHub API behind the agent's proxy
  githubEcho.port = 8093;

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

  # A repository the agent clones in place of one on GitHub
  agentRepo = pkgs.runCommand "agent-repo" { nativeBuildInputs = with pkgs; [ git ]; } ''
    git init -q -b master $out
    git -C $out -c user.name=test -c user.email=test@test commit -q --allow-empty -m first
  '';
in
pkgs.testers.runNixOSTest {
  name = "station-boot";

  imports = [
    (import ./sops-activation.nix { inherit pkgs fixtures; })
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
      (
        { config, ... }:
        {
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
            fileSystems."${agent.home}/.hermes" = station.config.fileSystems."${agent.home}/.hermes";
          };

          # The subvolumes that disko makes on the backup volume, made on the empty disk before
          # the units that use them
          systemd.services.backup-subvolumes =
            let
              users = [
                "syncthing.service"
                "restic-rest-server.socket"
                "radicale.service"
                "home-mya-.hermes.mount"
              ];
            in
            {
              requiredBy = users;
              before = users ++ [
                "btrbk-syncthing.service"
                "btrbk-restic.service"
                "btrbk-radicale.service"
              ];
              unitConfig = {
                RequiresMountsFor = [ "/srv/backup" ];
                # A service comes after basic.target, and so after every socket; this one comes
                # before the restic server's socket
                DefaultDependencies = false;
              };
              # Once per boot: a restart of Syncthing would run it again over the subvolumes
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
              };
              path = [ pkgs.btrfs-progs ];
              script =
                lib.concatMapStrings (name: ''
                  mkdir -p "$(dirname /srv/backup/${name})"
                  btrfs subvolume create /srv/backup/${name}
                '') (lib.attrNames config.disko.devices.disk.main.content.partitions.backup.content.subvolumes)
                + ''
                  chown mya:mya ${config.rokokol.mya-agent.hermes.backup.dataDir}
                '';
            };
        }
      )
      ({ config, ... }: {

        # sops-nix refuses a key in the store, so activation copies it to the host's path
        # before sops-nix reads it; the installer does the same with the real key
        system.activationScripts.testAgeKey.text = ''
          install -D -m 0400 ${fixtures}/key.txt /var/lib/sops-nix/key.txt
        '';
        system.activationScripts.setupSecretsForUsers.deps = [ "testAgeKey" ];

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

        rokokol.mya-agent.github.api = "http://127.0.0.1:${toString githubEcho.port}";
        systemd.services.github-echo = {
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            DynamicUser = true;
            ExecStart = "${lib.getExe pkgs.python3} ${./github-echo.py} ${toString githubEcho.port}";
          };
        };

        # The mirrors read the GitHub on the router, which is a private address that Forgejo
        # refuses to migrate from by default. A small page makes the list take several pages
        rokokol.forgejo-mirrors.githubApi = github.url;
        services.forgejo.settings.migrations.ALLOW_LOCALNETWORKS = true;
        systemd.services.forgejo-mirrors.environment.GITHUB_PER_PAGE = "2";

        # Prometheus finds the PC by its tailnet name, which here leads over the LAN
        networking.hosts."192.168.0.102" = [ "nixos-pc" ];

        environment.etc."test/mya-session-vars.json".text =
          builtins.toJSON
            config.home-manager.users.${agent.user}.home.sessionVariables;
        environment.etc."test/mya-skills.json".text = builtins.toJSON (
          lib.attrNames config.home-manager.users.${agent.user}.rokokol.agents.skills
        );

        rokokol.alert-mail.telegram.api = "http://192.168.0.1:${toString telegramPort}";

        # A unit that fails each time it runs and raises an alert as every watched unit does
        systemd.services.alert-probe = {
          unitConfig.OnFailure = "alert-mail@%n.service";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${pkgs.coreutils}/bin/false";
          };
        };

        # The fixtures hold a Syncthing key, as the real secrets will
        rokokol.syncthing.keyFromSops = true;

        sops.templates."hermes.env".content = ''
          OPENROUTER_BASE_URL=http://192.168.0.1:8094/v1
        '';
        services.hermes-agent.settings = {
          platforms.telegram.extra.base_url = "http://192.168.0.1:8094/bot";
          # The alert route only delivers; this one runs the agent, so the tests can type into it
          platforms.webhook.extra.routes.test = {
            prompt = "{text}";
            toolsets = [
              "terminal"
              "file"
              "web"
              "skills"
              "memory"
              "session_search"
            ];
            deliver = "log";
          };
          auxiliary = lib.mapAttrs (
            _: value:
            value
            // {
              base_url = "http://192.168.0.1:8094/v1";
            }
          ) station.config.services.hermes-agent.settings.auxiliary;
        };
        rokokol.mya-agent.hermes.monitor.api = "http://192.168.0.1:8094/v1";
        # The VM has no internet, so the agent clones a repository from the store. git trusts
        # it, though root owns it
        rokokol.mya-agent.repositories = lib.mkForce { huix = "${agentRepo}"; };
        programs.git = {
          enable = true;
          config.safe.directory = "${agentRepo}/.git";
        };
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
      telegramPort
      8094
    ];
    networking.firewall.allowedUDPPorts = [ 53 ];

    systemd.services.fake-hermes = {
      wantedBy = [ "multi-user.target" ];
      serviceConfig.ExecStart = "${lib.getExe pkgs.python3} ${./hermes-api.py} 8094";
    };

    # The Telegram Bot API: each request is one line of its path and form, answered with ok
    systemd.services.fake-telegram = {
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        StateDirectory = "fake-telegram";
        ExecStart = "${lib.getExe pkgs.python3} ${pkgs.writeText "fake-telegram.py" ''
          import http.server
          import urllib.parse

          class Handler(http.server.BaseHTTPRequestHandler):
              def do_POST(self):
                  body = self.rfile.read(int(self.headers["Content-Length"])).decode()
                  form = urllib.parse.parse_qs(body)
                  line = " ".join([self.path] + [f"{k}={v[0]!r}" for k, v in sorted(form.items())])
                  with open("/var/lib/fake-telegram/requests", "a") as log:
                      log.write(line + "\n")
                  self.send_response(200)
                  self.send_header("Content-Type", "application/json")
                  self.end_headers()
                  self.wfile.write(b'{"ok":true}')

          http.server.HTTPServer(("0.0.0.0", ${toString telegramPort}), Handler).serve_forever()
        ''}";
      };
    };

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
      ../../services/system/monitoring/node-exporter.nix
      ../../services/ai/mya-agent/agent.nix
      ../../services/ai/mya-agent/power.nix
      inputs.home-manager.nixosModules.home-manager
    ];
    _module.args.inputs = inputs;
    # The station's agent logs in to the workstations as this user
    rokokol.mya-agent.guest = {
      enable = true;
      loopbackPorts.probe = 8766;
      owner = "owner";
      shares = {
        Projects.path = "/home/owner/Projects";
        Downloads = {
          path = "/home/owner/Downloads";
          writable = true;
        };
      };
    };
    users.users.owner = {
      isNormalUser = true;
      # The power subtest logs in on the console
      password = "owner";
    };
    # Before the mounts, as the owner's real directories are: tmpfiles runs after them
    system.activationScripts.ownerShares = {
      deps = [ "users" ];
      text = "install -d -o owner -g users /home/owner/Projects /home/owner/Downloads";
    };
    # The guest prints through the scheduler's socket, which the firewall never sees
    services.printing.enable = true;
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

    # A peer of the archive with the vault's folder. Its identity is made at boot, so the test
    # pairs the two at run time; the station's own folders come from its configuration
    services.syncthing = {
      enable = true;
      openDefaultPorts = true;
      settings.folders.myWiki = {
        inherit (syncthing) id;
        path = "/var/lib/syncthing/myWiki";
      };
    };
    networking.hosts."192.168.0.104" = [ "nixos-station" ];
  };

  testScript = ''
    import base64
    import json
    import shlex
    import time
    from datetime import timedelta

    jq = "${lib.getExe pkgs.jq}"
    btrfs = "${pkgs.btrfs-progs}/bin/btrfs"
    map_logical ="${pkgs.btrfs-progs}/bin/btrfs-map-logical"
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

    with subtest("the mailbox file decrypts with the VM key and contains no real accounts"):
        assert json.loads(station.succeed("cat ${station.config.services.mail-agent.configFile}")) == {}
        station.succeed("test \"$(stat -c '%a %U %G' ${station.config.services.mail-agent.configFile})\" = '400 root root'")

    with subtest("the secretary gets communication, huix, research and Obsidian skills without workstation tools"):
        skills = set(json.loads(station.succeed("cat /etc/test/mya-skills.json")))
        assert {"calendar", "mail", "telegram", "contributing", "nix-best-practices", "tests", "papers", "obsidian-cli"} <= skills, skills
        assert not skills & {"3x-ui-admin", "super-productivity", "close-session", "headless-gui"}, skills

    with subtest("only the secretary may use the Telegram socket, not its credentials"):
        station.wait_for_unit("tg-agent.socket")
        socket = "${station.config.services.tg-agent.socketPath}"
        assert station.succeed(f"stat -c '%U %a' {socket}").strip() == "${agent.user} 600"
        station.succeed(f"runuser -u ${agent.user} -- test -w {socket}")
        station.fail(f"runuser -u rokokol -- test -w {socket}")
        for secret in ["telegram-api-id", "telegram-api-hash"]:
            station.succeed(f"test -s /run/secrets/{secret}")
            station.fail(f"runuser -u ${agent.user} -- cat /run/secrets/{secret}")

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

    # The node's client runs on the station, as the LAN cannot reach the server and the VMs have
    # no tailnet. The repository goes at the end, so the heartbeat subtests see no backup of pc
    with subtest("a node forgets its own backups, and the station keeps them a while in a snapshot"):
        restic = "RESTIC_REPOSITORY=rest:http://pc:test@127.0.0.1:8000/pc/ RESTIC_PASSWORD=node ${lib.getExe pkgs.restic}"
        station.succeed(f"echo kept >/tmp/node-file && {restic} init && {restic} backup /tmp/node-file")
        station.succeed("systemctl show -P OnFailure btrbk-restic.service | grep -qx 'alert-mail@btrbk-restic.service.service'")
        station.succeed(f"{btrfs} filesystem sync /srv/backup")
        assert run_to_end("btrbk-restic.service") == "success", "btrbk failed"
        taken = station.succeed("ls -d ${restic.snapshotDir}/restic.* | sort").split()[-1]
        station.succeed(f"{restic} forget latest --prune")
        station.succeed("test -z \"$(ls ${restic.dataDir}/pc/snapshots)\"")
        # The snapshot is a whole repository: restic reads it without the server
        station.succeed(f"RESTIC_PASSWORD=node ${lib.getExe pkgs.restic} -r {taken}/pc --no-lock restore latest --target /tmp/restored")
        station.succeed("grep -qx kept /tmp/restored/tmp/node-file")
        for user in ["restic", "rokokol"]:
            station.fail(f"runuser -u {user} -- {btrfs} subvolume delete {taken}")
            station.fail(f"runuser -u {user} -- rm -rf {taken}/pc")
        station.succeed("rm -rf ${restic.dataDir}/pc /tmp/node-file /tmp/restored")

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
        station.succeed("systemctl show -P OnFailure prometheus.service | grep -qx 'alert-mail@prometheus.service.service'")
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

    # A call to the Syncthing of a node, as a command; both nodes keep its configuration in the
    # default place, so the key is at the same path
    def st_curl(node, method, path, body=None):
        key = node.succeed("grep -oP '(?<=<apikey>)[^<]+' ${syncthing.config}").strip()
        data = f" -H 'Content-Type: application/json' -d {shlex.quote(json.dumps(body))}" if body is not None else ""
        return f"curl -sf -X {method} -H 'X-API-Key: {key}'{data} 'http://127.0.0.1:8384/rest/{path}'"

    def st(node, method, path, body=None):
        answer = node.succeed(st_curl(node, method, path, body))
        return json.loads(answer) if answer.strip() else None

    # The PC runs Syncthing as its default user, the station as the agent's
    def as_syncthing(node, command):
        user = "${syncthing.user}" if node is station else "syncthing"
        node.succeed(f"runuser -u {user} -- sh -c {shlex.quote(command)}")

    def pair(node, device, address):
        st(node, "POST", "config/devices", {"deviceID": device, "addresses": [address]})
        folder = st(node, "GET", "config/folders/${syncthing.id}")
        folder["devices"].append({"deviceID": device})
        st(node, "PUT", "config/folders/${syncthing.id}", folder)

    on_pc = "/var/lib/syncthing/myWiki"
    on_station = "${syncthing.path}"
    snapshots = "${syncthing.snapshotDir}"

    # btrbk sees a change once btrfs commits it, which it does every 30 seconds; the timer's next
    # run takes a change it missed, and the test commits at once
    def snapshot():
        # A run its timer began before the sync sees the old generation and makes no snapshot
        station.wait_until_succeeds(
            "case $(systemctl show -P ActiveState btrbk-syncthing.service) in active|activating) exit 1;; esac",
            timeout=timedelta(minutes=2),
        )
        station.succeed(f"{btrfs} filesystem sync /srv/backup")
        assert run_to_end("btrbk-syncthing.service") == "success", "btrbk failed"
        return station.succeed(f"ls -d {snapshots}/myWiki.* | sort").split()

    with subtest("the archive keeps each folder in a subvolume of the backup volume, the agent's to edit"):
        station.wait_for_unit("syncthing-init.service")
        for unit in ["syncthing", "btrbk-syncthing"]:
            station.succeed(f"systemctl show -P OnFailure {unit}.service | grep -qx 'alert-mail@{unit}.service.service'")
        station.succeed("systemctl is-active btrbk-syncthing.timer")
        for folder in st(station, "GET", "config/folders"):
            # The agent's edits go out to the peers
            assert folder["type"] == "sendreceive", f"{folder['id']} is {folder['type']}"
            owner = station.succeed(f"stat -c %U {shlex.quote(folder['path'])}").strip()
            assert owner == "${agent.user}", f"{folder['id']} belongs to {owner}"
            # The snapshots keep the history, so Syncthing keeps no versions of its own
            assert folder["versioning"]["type"] == "", f"{folder['id']} keeps {folder['versioning']['type']} versions"
            station.succeed(f"{btrfs} subvolume show {shlex.quote(folder['path'])}")
            station.succeed(f"findmnt -no TARGET -T {shlex.quote(folder['path'])} | grep -qx /srv/backup")

    # As on a host where the folders were another user's before the agent came
    with subtest("a folder another user left becomes Syncthing's whole when it starts"):
        # The directory above the folders, too, as a user who no longer exists left it
        parent = "${station.config.rokokol.syncthing.archive.dir}"
        station.succeed(f"systemctl stop syncthing.service && chown -R rokokol {on_station}")
        station.succeed(f"chown 4242:4242 {parent} && chmod 0750 {parent}")
        station.succeed("systemctl start syncthing.service")
        station.wait_for_unit("syncthing.service")
        stray = station.succeed(f"find {on_station} ! -user ${syncthing.user}").strip()
        assert stray == "", f"Syncthing left these to another user: {stray}"
        # The owner reads the folders through the group
        station.succeed(f"runuser -u rokokol -- ls {on_station}")

    with subtest("the LAN cannot reach the archive's Syncthing, and the archive reaches the PC"):
        pc.wait_for_unit("syncthing-init.service")
        pc.fail("timeout 5 bash -c '</dev/tcp/192.168.0.104/22000'")
        pc_id = st(pc, "GET", "system/status")["myID"]
        station_id = st(station, "GET", "system/status")["myID"]
        # Syncthing also dials from its listening port. A dial from 22000 to 22000 at once from both
        # ends makes one TCP simultaneous open, which the station's firewall lets in and which
        # fails as TLS from two clients. So only the station dials 22000: the PC gets a port the
        # firewall drops, and the real PC's entry, whose key the test PC lacks, goes
        st(station, "DELETE", "config/devices/${station.config.services.syncthing.settings.devices.nixos-pc.id}")
        pair(station, pc_id, "tcp://nixos-pc:22000")
        pair(pc, station_id, "tcp://nixos-station:22001")
        station.wait_until_succeeds(
            st_curl(station, "GET", "system/connections") + f" | {jq} -e '.connections[\"{pc_id}\"].connected'",
            timeout=timedelta(minutes=2),
        )

    # Private modes, as Claude Code gives its transcripts
    with subtest("what the PC overwrites or deletes stays in a snapshot, readable by the owner"):
        as_syncthing(pc, f"umask 077 && mkdir -p {on_pc}/notes && echo old >{on_pc}/notes/kept.md && echo gone >{on_pc}/notes/gone.md")
        for name, text in [("kept", "old"), ("gone", "gone")]:
            station.wait_until_succeeds(f"grep -qx {text} {on_station}/notes/{name}.md", timeout=timedelta(minutes=2))
        before = snapshot()[-1]
        as_syncthing(pc, f"echo new >{on_pc}/notes/kept.md && rm {on_pc}/notes/gone.md")
        station.wait_until_succeeds(f"grep -qx new {on_station}/notes/kept.md", timeout=timedelta(minutes=2))
        station.wait_until_succeeds(f"! test -e {on_station}/notes/gone.md", timeout=timedelta(minutes=2))
        for name, text in [("kept", "old"), ("gone", "gone")]:
            version = station.succeed(f"runuser -u rokokol -- cat {before}/notes/{name}.md")
            assert version == f"{text}\n", f"the snapshot kept {version!r} of {name}.md"
        station.succeed(f"test ! -e {on_station}/.stversions")

    with subtest("a snapshot is made only when its folder changed"):
        taken = snapshot()
        assert snapshot() == taken, "an unchanged folder got a new snapshot"

    # The account the agent shares with Syncthing, and the owner
    with subtest("neither Syncthing's account nor the owner can change or delete a snapshot"):
        newest = snapshot()[-1]
        for user in ["${syncthing.user}", "rokokol"]:
            station.fail(f"runuser -u {user} -- {btrfs} subvolume delete {newest}")
            station.fail(f"runuser -u {user} -- rm -rf {newest}/notes")
            station.fail(f"runuser -u {user} -- mv {newest} {on_station}/moved")
            # An older name in place would have btrbk itself delete the snapshot as expired
            station.fail(f"runuser -u {user} -- mv {newest} {snapshots}/myWiki.20000101T0000")
            station.fail(f"runuser -u {user} -- touch {snapshots}/myWiki.20000101T0000")
        station.fail(f"echo changed >{newest}/notes/kept.md")
        station.succeed(f"grep -qx new {newest}/notes/kept.md")

    agent_unit = "hermes-agent.service"
    agent_home = "${agent.home}"
    webhooks = "http://127.0.0.1:${toString station.config.rokokol.mya-agent.hermes.webhookPort}/webhooks"

    def type_in(text):
        import base64
        encoded = base64.b64encode(text.encode()).decode()
        station.succeed(f"${agent.notify} --url {webhooks}/test RUN:{encoded}")

    with subtest("Hermes starts without a shared Claude profile and mails root if it fails"):
        station.succeed(f"systemctl show -P OnFailure {agent_unit} | grep -qx 'alert-mail@{agent_unit}.service'")
        station.fail("test -e ${syncthing.shared}/settings.json")
        station.wait_for_unit(agent_unit)
        station.wait_until_succeeds("curl -sf http://127.0.0.1:${toString station.config.rokokol.mya-agent.hermes.webhookPort}/health", timeout=timedelta(minutes=2))
        station.fail("systemctl is-active mya-agent.service")
        as_syncthing(station, "echo '{}' >${syncthing.shared}/settings.json")

    with subtest("the bot answers the owner alone, from the start"):
        station.succeed("grep -qx 'TELEGRAM_ALLOWED_USERS=${agent.ownerChatId}' /etc/hermes/.env")
        station.succeed("test $(stat -Lc %a /etc/hermes/.env) = 440")
        station.fail("runuser -u nobody -- cat /etc/hermes/.env")

    with subtest("contributing in the agent's session finds its own private state"):
        variables = json.loads(station.succeed("cat /etc/test/mya-session-vars.json"))
        expected = variables["CONTRIB_HOME"].replace(agent_home, "${agent.workDir}", 1)
        type_in("${
          station.config.home-manager.users.${agent.user}.rokokol.agents.skills.contributing
        }/contrib.sh home >~/contrib-home")
        station.wait_until_succeeds(f"test -s {agent_home}/contrib-home", timeout=timedelta(seconds=30))
        actual = station.succeed(f"cat {agent_home}/contrib-home").strip()
        assert actual == expected, f"contributing uses {actual}, not {expected} from Home Manager"

    with subtest("Hermes can edit runtime settings without a Claude profile"):
        station.succeed("runuser -u ${agent.user} -- ${lib.getExe station.config.services.hermes-agent.package} config set curator.consolidate true")
        station.fail("test -e ${agent.home}/.claude")

    with subtest("the agent's repositories are cloned, and the owner fetches from them"):
        clone = f"{agent_home}/huix"
        station.wait_until_succeeds("systemctl show -P Result mya-agent-clone.service | grep -qx success")
        station.succeed(f"test $(stat -c %U {clone}) = ${agent.user}")
        # The group passes through the home to the clone, and lists nothing in the home
        station.succeed(f"runuser -u rokokol -- git -C {clone} log -1 --format=%s | grep -qx first")
        station.fail(f"runuser -u rokokol -- ls {agent_home}")
        # A commit the agent makes in its sandbox, whose umask is 0077, stays readable to the owner
        type_in("cd ~/huix && git commit -q --allow-empty -m from-the-session && echo done >~/committed")
        station.wait_until_succeeds(f"grep -qx done {agent_home}/committed", timeout=timedelta(minutes=1))
        station.succeed(f"runuser -u rokokol -- git -C {clone} log -1 --format=%s | grep -qx from-the-session")
        station.succeed(f"runuser -u rokokol -- git -C {clone} status --short")

    with subtest("the owner starts the agent's sync and no other verb, and the agent's work is committed as the agent's"):
        clone = f"{agent_home}/huix"
        station.succeed(f"runuser -u ${agent.user} -- sh -c 'echo work >{clone}/agent-work.txt'")
        station.succeed("runuser -u rokokol -- systemctl start ${agent.syncUnit}")
        subject = station.succeed(f"runuser -u rokokol -- git -C {clone} log -1 --format=%s").strip()
        assert subject.startswith("[${agent.user}] sync "), f"the agent's commit reads {subject!r}"
        station.succeed(f"runuser -u rokokol -- git -C {clone} show HEAD:agent-work.txt | grep -qx work")
        station.fail("runuser -u rokokol -- systemctl restart ${agent.syncUnit}")
        station.fail("runuser -u rokokol -- systemctl start mya-agent-clone.service")

    with subtest("a signed alert reaches the chat without an agent run, and an unsigned request is rejected"):
        station.succeed(f"curl -s -o /tmp/rejected -w '%{{http_code}}' -H 'Content-Type: application/json' -d '{{}}' {webhooks}/alerts | grep -qx 401")
        sessions = f"${lib.getExe pkgs.sqlite} {agent_home}/.hermes/state.db 'select count(*) from sessions'"
        before = station.succeed(sessions).strip()
        # A word with no MarkdownV2 character, which Telegram delivery would escape
        station.succeed("${agent.notify} probealert")
        router.wait_until_succeeds(
            "journalctl -u fake-hermes -o cat | grep -qxF 'sent to ${toString station.config.rokokol.mya-agent.hermes.reportsTopic}: Station alert: probealert'",
            timeout=timedelta(minutes=1),
        )
        assert station.succeed(sessions).strip() == before, "the alert started an agent session"
        type_in("echo 'semi;colon \"Enter\" $x' >~/typed")
        station.wait_until_succeeds(f"test -s {agent_home}/typed", timeout=timedelta(seconds=30))
        typed = station.succeed(f"cat {agent_home}/typed")
        assert typed == "semi;colon \"Enter\" $x\n", f"the session got {typed!r}"
        station.fail("runuser -u rokokol -- ${agent.notify} text")

    with subtest("the old morning timer is absent"):
        station.fail("systemctl cat morning-letter.timer")

    with subtest("the gateway executes an editable cron job inside its sandbox"):
        prompt = "RUN:" + base64.b64encode(b"readlink /proc/self/ns/user >~/cron-namespace; echo cron-ran >~/cron-probe").decode()
        hermes = "runuser -u ${agent.user} -- ${lib.getExe station.config.services.hermes-agent.package}"
        schedule = station.succeed("date -d '+5 seconds' --iso-8601=seconds").strip()
        station.succeed(f"{hermes} cron create {shlex.quote(schedule)} {shlex.quote(prompt)} --name vm-cron --deliver local --repeat 1")
        store = json.loads(station.succeed("cat ${agent.stateDir}/cron/jobs.json"))
        jobs = store["jobs"] if isinstance(store, dict) else store
        assert any(job["name"] == "vm-cron" for job in jobs)
        station.wait_until_succeeds("grep -qx cron-ran ${agent.home}/cron-probe", timeout=timedelta(minutes=2))
        gateway_ns = station.succeed(f"readlink /proc/$(systemctl show -P MainPID {agent_unit})/ns/user").strip()
        assert station.succeed("cat ${agent.home}/cron-namespace").strip() == gateway_ns

    with subtest("gh in the session reaches GitHub through the proxy, which picks the token by path"):
        station.wait_for_unit("github-echo.service")
        station.wait_for_open_port(${toString githubEcho.port})
        type_in("{ gh api /notifications >~/gh-classic; gh api /user >~/gh-read; } 2>~/gh-errors; env >~/gh-env")
        station.wait_until_succeeds(f"test -s {agent_home}/gh-env", timeout=timedelta(seconds=30))
        station.succeed(f"cat {agent_home}/gh-errors")
        classic = json.loads(station.succeed(f"cat {agent_home}/gh-classic"))
        read = json.loads(station.succeed(f"cat {agent_home}/gh-read"))
        assert classic["authorization"] == "token ghp_test", f"the inbox went with {classic}"
        assert read["authorization"] == "token github_pat_test", f"a read went with {read}"
        # Neither token is in the session, in its variables or in a file it can read
        station.fail(f"grep -q -e github_pat_test -e ghp_test {agent_home}/gh-env")
        for secret in ["github-token", "github-token-classic"]:
            station.fail(f"runuser -u ${agent.user} -- cat /run/secrets/{secret}")
        # The socket's directory admits the agent's group alone, which the owner is in as well
        station.fail("runuser -u nobody -- ${lib.getExe pkgs.curl} -sf --unix-socket ${station.config.rokokol.mya-agent.github.socket} http://api.github.com/user")

    with subtest("the session edits the vault and cannot reach shared history, backups or outside user services"):
        station.succeed("install -m 0600 -o rokokol /dev/null /home/rokokol/.owner-only")
        syncthing_pid = station.succeed("systemctl show -P MainPID syncthing.service").strip()
        uid = station.succeed("id -u ${agent.user}").strip()
        station.wait_for_unit(f"user@{uid}.service")
        manager_pid = station.succeed(f"systemctl show -P MainPID user@{uid}.service").strip()
        type_in(f"sh ${agent.probe} {syncthing_pid} {manager_pid}")
        station.wait_until_succeeds(f"test -e {agent_home}/probe", timeout=timedelta(seconds=30))
        found = dict(line.split("=", 1) for line in station.succeed(f"cat {agent_home}/probe").split())
        reachable = {"write-vault", "wake-pc", "pc-mac"}
        hidden = {"bot-token-env", "read-shared", "write-shared", "external-skills", "sops-key", "owner-home", "snapshots", "restic", "syncthing-key", "syncthing-root", "user-manager-root", "user-manager-spawn", "new-privileges"}
        expected = {"user": "${agent.user}"} | dict.fromkeys(reachable, "yes") | dict.fromkeys(hidden, "no")
        assert found == expected, f"the session sees {found}, not {expected}"

    with subtest("what the session writes reaches the PC, and a snapshot keeps it"):
        pc.wait_until_succeeds(f"grep -qx agent {on_pc}/agent.md", timeout=timedelta(minutes=2))
        newest = snapshot()[-1]
        station.succeed(f"grep -qx agent {newest}/agent.md")

    with subtest("restarting Hermes keeps its mutable state and the service recovers"):
        before = station.succeed(f"systemctl show -P MainPID {agent_unit}").strip()
        station.succeed(f"systemctl restart {agent_unit}")
        station.wait_until_succeeds(
            f"pid=$(systemctl show -P MainPID {agent_unit}); [ \"$pid\" != 0 ] && [ \"$pid\" != {before} ]",
            timeout=timedelta(minutes=1),
        )
        station.wait_until_succeeds(
            "curl -sf http://127.0.0.1:${toString station.config.rokokol.mya-agent.hermes.webhookPort}/health",
            timeout=timedelta(minutes=2),
        )
        type_in("echo fresh >~/fresh")
        station.wait_until_succeeds(f"grep -qx fresh {agent_home}/fresh", timeout=timedelta(seconds=30))
        assert station.succeed(f"systemctl show -P ActiveState {agent_unit}").strip() == "active"

    with subtest("Hermes merges Nix settings without removing user settings"):
        yq = "${lib.getExe pkgs.yq-go}"
        config_yaml = f"{agent_home}/.hermes/config.yaml"
        station.succeed(f"systemctl stop {agent_unit}")
        assert station.succeed(f"systemctl show -P Result {agent_unit}").strip() == "success"
        station.succeed(f"{yq} -i '.memory.nudge_interval = 3 | .memory.user_note = \"kept\" | .mcp_servers.dav.command = \"changed\" | .mcp_servers.dav.enabled = false | .mcp_servers.personal.command = \"personal\"' {config_yaml}")
        station.succeed("systemctl restart hermes-state.service")
        assert station.succeed(f"{yq} .memory.nudge_interval {config_yaml}").strip() == "10"
        assert station.succeed(f"{yq} .memory.user_note {config_yaml}").strip() == "kept"
        assert station.succeed(f"{yq} .mcp_servers.dav.command {config_yaml}").strip() == "${station.config.services.hermes-agent.settings.mcp_servers.dav.command}"
        assert station.succeed(f"{yq} .mcp_servers.dav.enabled {config_yaml}").strip() == "false"
        assert station.succeed(f"{yq} .mcp_servers.personal.command {config_yaml}").strip() == "personal"
        station.succeed(f"{yq} -i 'del(.mcp_servers.personal, .mcp_servers.dav.enabled, .memory.user_note)' {config_yaml}")
        station.succeed(f"systemctl start {agent_unit}")
        station.wait_until_succeeds("curl -sf http://127.0.0.1:${toString station.config.rokokol.mya-agent.hermes.webhookPort}/health", timeout=timedelta(minutes=2))

    with subtest("Hermes starts with the settings declared in Nix"):
        assert station.succeed(f"{yq} .memory.provider {config_yaml}").strip() == "builtin"
        assert station.succeed(f"{yq} .curator.consolidate {config_yaml}").strip() == "true"
        assert station.succeed(f"{yq} .memory.user_char_limit {config_yaml}").strip() == "24000"
        assert station.succeed(f"{yq} .agent.reasoning_effort {config_yaml}").strip() not in {"", "null"}
        assert station.succeed(f"{yq} .cron.wrap_response {config_yaml}").strip() == "false"
        station.succeed(f"{yq} -e .mcp_servers.dav {config_yaml}")

    hermes_restic = "RESTIC_PASSWORD_FILE=${station.config.sops.secrets.hermes-restic-password.path} ${lib.getExe pkgs.restic} -r ${restic.dataDir}/station"

    with subtest("Hermes state reaches its local restic repository and the portable archive is valid"):
        station.succeed(f"runuser -u ${agent.user} -- sh -c 'echo restore-marker >{agent_home}/.hermes/SOUL.md'")
        station.succeed(f"runuser -u ${agent.user} -- sh -c 'echo restore-user >{agent_home}/.hermes/memories/USER.md'")
        station.succeed(f"runuser -u ${agent.user} -- sh -c 'echo restore-memory >{agent_home}/.hermes/memories/MEMORY.md'")
        station.succeed("systemctl start restic-backups-hermes.service")
        station.succeed("test -s /var/cache/hermes-backup/current.zip")
        station.succeed("${lib.getExe pkgs.python3} -c 'import zipfile; z=zipfile.ZipFile(\"/var/cache/hermes-backup/current.zip\"); assert z.testzip() is None; assert any(p.endswith(\"state.db\") for p in z.namelist())'")
        station.succeed(f"{hermes_restic} snapshots --json | ${lib.getExe pkgs.jq} -e 'length > 0'")

    with subtest("a new machine gets the whole Hermes state back from restic"):
        station.succeed(f"{hermes_restic} restore latest --target /root/restore")
        station.succeed(f"install -m 0600 -o ${agent.user} -g ${agent.user} /root/restore/var/cache/hermes-backup/current.zip {agent_home}/hermes.zip")
        # An empty state that activation and the first start fill, as after an install
        station.succeed(f"systemctl stop {agent_unit}")
        station.succeed(f"find {agent_home}/.hermes -mindepth 1 -delete")
        station.succeed(f"systemctl restart hermes-state.service && systemctl start {agent_unit}")
        station.wait_until_succeeds(f"test -e {agent_home}/.hermes/state.db", timeout=timedelta(minutes=1))
        station.fail(f"grep -q restore-marker {agent_home}/.hermes/SOUL.md")
        station.succeed(f"systemctl stop {agent_unit}")
        # Hermes copies its bundled skills with the store's read-only modes
        station.succeed(f"runuser -u ${agent.user} -- chmod -R u+w {agent_home}/.hermes")
        station.succeed(f"runuser -u ${agent.user} -- env HOME={agent_home} ${lib.getExe station.config.services.hermes-agent.package} import --force {agent_home}/hermes.zip")
        station.succeed(f"rm {agent_home}/hermes.zip && systemctl restart hermes-state.service && systemctl start {agent_unit}")
        station.succeed(f"grep -qx restore-marker {agent_home}/.hermes/SOUL.md")
        station.succeed(f"grep -qx restore-user {agent_home}/.hermes/memories/USER.md")
        station.succeed(f"grep -qx restore-memory {agent_home}/.hermes/memories/MEMORY.md")
        station.wait_until_succeeds(
            "curl -sf http://127.0.0.1:${toString station.config.rokokol.mya-agent.hermes.webhookPort}/health",
            timeout=timedelta(minutes=2),
        )

    with subtest("the archive ignores what the workstations ignore, once their list arrives"):
        # Until then the folder runs: an include of a missing file would stop it
        station.fail(f"test -e {on_station}/.stignore")
        state = st(station, "GET", "db/status?folder=${syncthing.id}")
        assert state["state"] != "error", f"the folder stopped: {state.get('error')}"
        as_syncthing(pc, f"echo ignored.md >{on_pc}/.stignore-shared")
        station.wait_until_succeeds(
            f"grep -qx '#include .stignore-shared' {on_station}/.stignore", timeout=timedelta(minutes=2)
        )
        as_syncthing(station, f"echo local >{on_station}/ignored.md && echo local >{on_station}/sent.md")
        pc.wait_until_succeeds(f"test -e {on_pc}/sent.md", timeout=timedelta(minutes=2))
        pc.fail(f"test -e {on_pc}/ignored.md")

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

    calendars = "http://100.64.0.1:${toString radicale.port}"
    dav = "curl -s --interface 100.64.0.1 -o /dev/null -w '%{http_code}'"
    mkcalendar = (
        "<c:mkcalendar xmlns:c='urn:ietf:params:xml:ns:caldav' xmlns:d='DAV:'><d:set><d:prop>"
        "<c:supported-calendar-component-set><c:comp name='{}'/></c:supported-calendar-component-set>"
        "</d:prop></d:set></c:mkcalendar>"
    )
    todos = (
        "<c:calendar-query xmlns:c='urn:ietf:params:xml:ns:caldav' xmlns:d='DAV:'><d:prop><c:calendar-data/></d:prop>"
        "<c:filter><c:comp-filter name='VCALENDAR'><c:comp-filter name='VTODO'/></c:comp-filter></c:filter></c:calendar-query>"
    )

    with subtest("Radicale listens on loopback alone, and its site asks every client for a login"):
        station.wait_for_unit("radicale.service")
        station.succeed("systemctl show -P OnFailure radicale.service | grep -qx 'alert-mail@radicale.service.service'")
        listeners = station.succeed("ss -Hltn 'sport = :${lib.last (lib.splitString ":" radicale.backend)}' | awk '{ print $4 }'").split()
        assert listeners == ["${radicale.backend}"], f"Radicale listens on {listeners}"
        for login in ["", "-u rokokol:wrong", "-u mya:wrong"]:
            code = station.succeed(f"{dav} {login} -X PROPFIND {calendars}/rokokol/")
            assert code == "401", f"Radicale answered {code} to a PROPFIND with login {login!r}"
        # The disk layout makes the subvolume as root's, and the service gives it to its own user
        owner = station.succeed("stat -c %U ${radicale.dataDir}").strip()
        assert owner == "radicale", f"the calendars belong to {owner}"

    with subtest("the agent's home is the owner's, so a calendar either makes is the other's too"):
        for name, kind in [("schedule", "VEVENT"), ("todo", "VTODO")]:
            body = shlex.quote(mkcalendar.format(kind))
            code = station.succeed(f"{dav} -u rokokol:test -X MKCALENDAR --data {body} {calendars}/rokokol/{name}/")
            assert code == "201", f"the owner got {code} making {name}"
        code = station.succeed(f"{dav} -u mya:test -X MKCALENDAR --data {shlex.quote(mkcalendar.format('VTODO'))} {calendars}/mya/made/")
        assert code == "201", f"the agent got {code} making a calendar"
        station.succeed("test -L ${radicale.dataDir}/collection-root/${agent.user}")
        station.succeed("test -d ${radicale.dataDir}/collection-root/rokokol/made")

    with subtest("the agent's dav-mcp lists the owner's calendars and adds a task the owner sees"):
        # Use the entry's variables and wrapper from the Hermes session
        entry = json.loads(station.succeed("${lib.getExe pkgs.yq-go} -o json -I 0 .mcp_servers.dav ${radicale.mcpConfig}"))
        variables = " ".join(f"{name}={shlex.quote(value)}" for name, value in entry["env"].items())
        calls = [
            {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {"name": "test", "version": "0"}}},
            {"jsonrpc": "2.0", "method": "notifications/initialized"},
            {"jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": {"name": "list_calendars", "arguments": {}}},
            {"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {"name": "create_todo", "arguments": {"calendar_url": entry["env"]["CALDAV_SERVER_URL"] + "mya/todo/", "summary": "Task from the agent"}}},
        ]
        lines = " ".join(shlex.quote(json.dumps(call)) for call in calls)
        type_in(f"printf '%s\\n' {lines} | env {variables} {entry['command']} >~/dav-reply 2>~/dav-log")
        station.wait_until_succeeds(f"grep -q '\"id\":3' {agent_home}/dav-reply", timeout=timedelta(minutes=1))
        replies = {r["id"]: r for r in map(json.loads, station.succeed(f"cat {agent_home}/dav-reply").split("\n")[:-1]) if "id" in r}
        listed = replies[2]["result"]["content"][0]["text"]
        for name in ["schedule", "todo", "made"]:
            assert f"/mya/{name}/" in listed, f"dav-mcp lists no {name}: {listed}"
        assert not replies[3]["result"].get("isError"), f"dav-mcp made no task: {replies[3]}"
        report = station.succeed(
            f"curl -sf --interface 100.64.0.1 -u rokokol:test -X REPORT -H 'Depth: 1' --data {shlex.quote(todos)} {calendars}/rokokol/todo/"
        )
        assert "Task from the agent" in report, f"the owner sees no task of the agent: {report}"

    with subtest("a snapshot keeps an event that a client deleted"):
        station.succeed("systemctl show -P OnFailure btrbk-radicale.service | grep -qx 'alert-mail@btrbk-radicale.service.service'")
        event = "\r\n".join([
            "BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//test//EN",
            "BEGIN:VEVENT", "UID:kept", "DTSTAMP:20261020T090000Z", "DTSTART:20261021T090000Z",
            "DTEND:20261021T100000Z", "SUMMARY:Kept event", "END:VEVENT", "END:VCALENDAR", "",
        ])
        station.succeed(f"printf '%s' {shlex.quote(event)} >/tmp/kept.ics")
        code = station.succeed(f"{dav} -u rokokol:test -T /tmp/kept.ics -H 'Content-Type: text/calendar' {calendars}/rokokol/schedule/kept.ics")
        assert code == "201", f"the owner got {code} adding an event"
        station.succeed(f"{btrfs} filesystem sync /srv/backup")
        assert run_to_end("btrbk-radicale.service") == "success", "btrbk failed"
        taken = station.succeed("ls -d ${radicale.snapshotDir}/radicale.* | sort").split()[-1]
        code = station.succeed(f"{dav} -u mya:test -X DELETE {calendars}/mya/schedule/kept.ics")
        assert code in ("200", "204"), f"the agent got {code} deleting the event"
        station.fail("test -e ${radicale.dataDir}/collection-root/rokokol/schedule/kept.ics")
        station.succeed(f"grep -q 'Kept event' {taken}/collection-root/rokokol/schedule/kept.ics")
        station.succeed("rm /tmp/kept.ics")

    with subtest("Grafana shows Prometheus to anyone on the tailnet or the LAN, and only the admin may change it"):
        station.wait_for_unit("grafana.service")
        station.succeed("systemctl show -P OnFailure grafana.service | grep -qx 'alert-mail@grafana.service.service'")
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

    # The panels that must show a series here, by dashboard. A VM has no CPU sensor and no SMART,
    # the PC here no GPU, no node pushes before the Pushgateway subtest, and the hourly
    # heartbeat has not run yet, so those may be empty, but never with an error
    filled = {
        "hosts": {"CPU", "Memory", "Swap traffic", "Disks"},
        "guards": {
            "Watched units",
            "RAM that zram takes",
            "Peers",
            "What each folder still needs",
            # The archive subtests above ran btrbk, which writes these after each run
            "Snapshots of each archived folder",
            "Age of each folder's newest snapshot",
        },
        "mail": set(),
        "vpn": set(),
    }
    for uid, full in filled.items():
      with subtest(f"the {uid} dashboard is there for a viewer, and each of its queries runs in Prometheus"):
        with open(f"${grafana.dashboards}/{uid}.json") as listing:
            dashboard = json.load(listing)
        code = station.succeed(
            "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:${toString grafana.backendPort}/api/dashboards/uid/"
            + dashboard["uid"]
        )
        assert code == "200", f"a viewer got {code} for the dashboard"
        # The station stands for every host, the PC for every GPU and the PC's login for every node
        values = {"$host": "nixos-station", "$gpu_host": "nixos-pc", "$instance": "pc", "$__rate_interval": "2m"}
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
                    if panel["title"] not in full or result["data"]["result"]:
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
        # The run that failed above is a problem until it is closed, and an open one is not sent
        station.succeed("systemctl start alert-reconcile.service")
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
        station.succeed("su - rokokol -c 'wake-pc send'")
        pc.wait_until_succeeds(
            "test -s /tmp/wol.pcap && tcpdump -n -r /tmp/wol.pcap | grep -q '192.168.0.104.* > 192.168.0.255.9'",
            timeout=timedelta(seconds=30),
        )
        station.fail("su - nobody -s /bin/sh -c 'cat /run/secrets/pc-mac'")

    with subtest("the LAN broadcast address is bound to the wired link before any TUN rule"):
        station.succeed("ip route get 192.168.0.255 | grep -q 'broadcast 192.168.0.255 dev lan table local'")

    with subtest("a failed unit mails root through the relay and tells Telegram, once"):
        # alert-probe fails each time it runs and raises an alert like every watched unit
        station.fail("systemctl start alert-probe.service")
        router.wait_until_succeeds(
            "curl -s http://127.0.0.1:8025/api/v1/messages | grep -qF '[nixos-station] alert-probe.service failed'",
            timeout=timedelta(minutes=1),
        )
        assert "failed (attempt" not in mails(), "a mail sent at the first try names an attempt"
        router.wait_until_succeeds(
            "grep -F 'alert-probe.service failed' /var/lib/fake-telegram/requests"
            " | grep -F \"chat_id='${agent.ownerChatId}'\" | grep -qF '/bot123456789:test-token/sendMessage'",
            timeout=timedelta(minutes=1),
        )
        # grep reads the whole list: with -q it would close the pipe early and fail the writer
        station.succeed("su - rokokol -c 'alert list' | grep '^unit:alert-probe.service'")
        # The problem stays open until the unit recovers, and then closes once
        station.succeed("systemctl reset-failed alert-probe.service")
        station.succeed("systemctl start alert-reconcile.service")
        router.wait_until_succeeds(
            "curl -s http://127.0.0.1:8025/api/v1/messages | grep -qF 'alert-probe.service failed (resolved)'",
            timeout=timedelta(minutes=1),
        )
        assert "unit:alert-probe.service" not in station.succeed("alert list"), "the problem stayed open"

    with subtest("each backup problem is an alert of its own, sent once"):
        # The VM's one node never pushed, and its backup volume is small: two causes. An hourly
        # run may have opened them already, so the list is emptied and its causes closed first
        causes = "${station.config.rokokol.backup-heartbeat.causesFile}"
        station.succeed("systemctl stop backup-heartbeat.timer")
        station.succeed(f"if [ -e {causes} ]; then : >{causes}; fi")
        station.succeed("systemctl start alert-reconcile.service")
        station.fail("alert list | grep '^backup:'")
        # The closes mail in deliveries of their own, and one that lands after the mailbox is
        # emptied would count against the second run below. A message leaves the outbox when
        # its delivery ends
        station.wait_until_succeeds(
            "test -z \"$(ls -A /var/lib/alerts/outbox 2>/dev/null)\"", timeout=timedelta(minutes=1)
        )
        router.succeed("curl -sf -X DELETE http://127.0.0.1:8025/api/v1/messages")
        station.succeed("systemctl start backup-heartbeat.service")
        for subject in ["the backup of pc has no snapshot", "free for the backups"]:
            router.wait_until_succeeds(
                f"curl -s http://127.0.0.1:8025/api/v1/messages | grep -qF {shlex.quote(subject)}",
                timeout=timedelta(minutes=1),
            )
        station.succeed("alert list | grep '^backup:pc-missing'")
        station.succeed("alert list | grep '^backup:low-space'")
        # A second run finds the same causes and sends nothing
        station.succeed("systemctl start backup-heartbeat.service")
        station.succeed("systemctl start alert-reconcile.service")
        sent = json.loads(mails())["messages"]
        assert len(sent) == 2, f"the second run sent mail again: {[m['Subject'] for m in sent]}"

    with subtest("a mail that waits for its relay holds up neither Telegram nor the next alert"):
        alert = "alert-mail@alert-probe.service.service"
        # The mail of the subtest above would match the search below on its own
        router.succeed("curl -sf -X DELETE http://127.0.0.1:8025/api/v1/messages")
        assert "alert-probe" not in mails(), "the mailbox kept the earlier alert"
        router.succeed(": >/var/lib/fake-telegram/requests")
        router.succeed("systemctl stop mailpit-trap.service")
        since = station.succeed("date +%s").strip()
        station.fail("systemctl start alert-probe.service")
        station.wait_until_succeeds(
            f"journalctl --since @{since} | grep -qF 'next try in'", timeout=timedelta(minutes=1)
        )
        # The unit that raised the alert is done; the mail waits in a delivery of its own
        station.wait_until_succeeds(f"test $(systemctl show -P ActiveState {alert}) = inactive", timeout=timedelta(minutes=1))
        assert (result := station.succeed(f"systemctl show -P Result {alert}").strip()) == "success", f"{alert} ended with {result}"
        station.succeed("test -n \"$(ls /var/lib/alerts/outbox)\"")
        # Telegram has the first alert, and a second one, while the first mail still waits
        station.succeed("echo 'second' | alert raise probe:second '[nixos-station] a second probe'")
        for subject in ["alert-probe.service failed", "a second probe"]:
            router.wait_until_succeeds(
                f"grep -qF {shlex.quote(subject)} /var/lib/fake-telegram/requests", timeout=timedelta(minutes=1)
            )
        router.succeed("systemctl start mailpit-trap.service")
        router.wait_for_open_port(1025)
        # The subject says which try got through and how late the alert is
        router.wait_until_succeeds(
            "curl -s http://127.0.0.1:8025/api/v1/messages"
            " | grep -qE '\\[nixos-station\\] alert-probe.service failed \\(attempt [2-9], [0-9]+ min late\\)'",
            timeout=timedelta(minutes=3),
        )
        station.wait_until_succeeds("test -z \"$(ls /var/lib/alerts/outbox)\"", timeout=timedelta(minutes=3))
        station.succeed("alert clear probe:second")
        station.succeed("systemctl reset-failed alert-probe.service")

    with subtest("the digest lists the open problems, quiet ones too, and says nothing when none is"):
        # The timers would open or close problems in the middle of the subtest; with them held,
        # every failed unit reset and every list of causes emptied, the reconcile closes
        # whatever the subtests above left open
        station.succeed("systemctl stop alert-reconcile.timer node-push-watch.timer")
        station.succeed("systemctl reset-failed")
        for causes in ${lib.escapeShellArg (lib.concatStringsSep " " (lib.attrValues station.config.rokokol.alert-mail.sources))}.split():
            station.succeed(f"if [ -e {causes} ]; then : >{causes}; fi")
        station.succeed("systemctl start alert-reconcile.service")
        left = station.succeed("alert list")
        assert left == "", f"problems stayed open with every unit reset:\n{left}"
        router.succeed("curl -sf -X DELETE http://127.0.0.1:8025/api/v1/messages")
        station.succeed("echo 'probe body' | alert raise -q probe:quiet '[nixos-station] a quiet probe'")
        station.succeed("systemctl start alert-reconcile.service")
        assert "a quiet probe" not in mails(), "a quiet problem was mailed when it opened"
        station.succeed("systemctl start alert-digest.service")
        router.wait_until_succeeds(
            "curl -s http://127.0.0.1:8025/api/v1/messages | grep -qF '[nixos-station] 1 unresolved'",
            timeout=timedelta(minutes=1),
        )
        station.succeed("alert clear probe:quiet")
        router.succeed("curl -sf -X DELETE http://127.0.0.1:8025/api/v1/messages")
        station.succeed("systemctl start alert-digest.service")
        assert "unresolved" not in mails(), "a digest of nothing was mailed"
        journal = station.succeed("cut -f2,3 /var/lib/alerts/journal")
        assert "OPEN\tprobe:quiet\nRESOLVED\tprobe:quiet" in journal, f"the journal is\n{journal}"
        station.succeed("systemctl start alert-reconcile.timer backup-heartbeat.timer node-push-watch.timer")

    with subtest("a smartd alert raised while the relay is down arrives once it is up"):
        # smartd is off in the VM, so its mailer is called the way smartd calls it
        mailer = "${station.config.services.smartd.notifications.mail.mailer}"
        subject = "smartd probe of a failing disk"
        router.succeed("curl -sf -X DELETE http://127.0.0.1:8025/api/v1/messages")
        router.succeed("systemctl stop mailpit-trap.service")
        # The subtest above logged a retry of its own, so the journal is read from here on
        since = station.succeed("date +%s").strip()
        # smartd waits for its mailer, so the mailer hands the mail off and returns at once
        station.succeed(f"printf 'To: root\\nSubject: {subject}\\n\\nprobe\\n' | timeout 10 {mailer} -i root")
        station.wait_until_succeeds(
            f"journalctl --since @{since} | grep -qF 'next try in'", timeout=timedelta(minutes=1)
        )
        router.succeed("systemctl start mailpit-trap.service")
        router.wait_for_open_port(1025)
        router.wait_until_succeeds(
            "curl -s http://127.0.0.1:8025/api/v1/messages"
            f" | grep -qE '{subject} \\(attempt [2-9], [0-9]+ min late\\)'",
            timeout=timedelta(minutes=3),
        )

    with subtest("the station's Syncthing takes its key from sops, so its device ID outlives a reinstall"):
        station.wait_for_unit("syncthing.service")
        found = station.succeed(
            "${station.config.services.syncthing.package}/bin/syncthing device-id"
            " --home=${station.config.services.syncthing.configDir}"
        ).strip()
        with open("${fixtures}/syncthing-device-id") as listing:
            wanted = listing.read().strip()
        assert found == wanted, f"the station came up as {found}, not as {wanted} from its key"

    with subtest("the heartbeat's numbers reach Prometheus through the textfile directory"):
        # The heartbeat ran in the subtests above; its file lives apart and is linked in
        station.succeed("test -s ${station.config.rokokol.node-exporter.textfileDir}/backup.prom")
        repositories = set(station.succeed("cut -d: -f1 ${station.config.sops.secrets.restic-server-htpasswd.path}").split()) - {"metrics"}
        assert repositories, "the backup server has no expected repository"
        wait_for_series('count by (host) (backup_last_snapshot_timestamp_seconds)', {"nixos-station": len(repositories)})
        wait_for_series('count by (host) (backup_free_bytes)', {"nixos-station": 1.0})

    with subtest("the nodes push to the Pushgateway, each only under its own name"):
        # The fixtures' htpasswd has the one node pc, with the password test. The tailnet
        # address is the dummy link of the tailnet-web subtest
        gateway = "http://100.64.0.1:${toString station.config.rokokol.pushgateway.port}"
        watch = "node-push-watch.service"

        def push(path, auth="-u pc:test", method="POST", body="probe_value 1"):
            return station.succeed(
                f"printf '%s\\n' {shlex.quote(body)} | curl -s -o /dev/null -w '%{{http_code}}' --interface 100.64.0.1"
                f" -X {method} {auth} --data-binary @- {gateway}{path}"
            ).strip()

        # The watch lists its causes for the alert registry, which opens and closes each one
        station.succeed(f"systemctl show -P OnFailure {watch} | grep -qx 'alert-mail@{watch}.service'")
        station.wait_for_unit("pushgateway.service")
        result = run_to_end(watch)
        assert result == "success", f"{watch} failed with only a silent node to report: {result}"
        station.wait_until_succeeds("alert list | grep '^node:pc-silent'", timeout=timedelta(minutes=1))

        assert (code := push("/metrics/job/node/instance/pc")) == "200", f"the node's own push got {code}"
        refused = {
            "another node's group": push("/metrics/job/node/instance/other"),
            "a group with no instance": push("/metrics/job/node"),
            "the whole gateway": push("/metrics", method="DELETE"),
            "a read of the page": push("/metrics", method="GET"),
        }
        assert set(refused.values()) == {"403"}, f"nginx let through: {refused}"
        # nginx compares the path with the login before it checks the password, so a request with
        # no login is refused by the path, and one with the wrong password by the password
        assert (code := push("/metrics/job/node/instance/pc", "")) == "403", f"no login got {code}"
        assert (code := push("/metrics/job/node/instance/pc", "-u pc:wrong")) == "401", f"a wrong password got {code}"
        page = station.succeed("curl -sf http://${station.config.services.prometheus.pushgateway.web.listen-address}/metrics")
        assert 'instance="other"' not in page, "a refused push reached the gateway"

        result = run_to_end(watch)
        assert result == "success", f"{watch} ended with {result} after the node pushed"
        station.wait_until_succeeds("! alert list | grep '^node:pc-silent'", timeout=timedelta(minutes=1))
        station.wait_until_succeeds(
            "curl -sf --get --data-urlencode 'query=push_time_seconds{job=\"node\",instance=\"pc\"}' ${prometheus}/api/v1/query"
            " | grep -q '\"instance\":\"pc\"'",
            timeout=timedelta(minutes=2),
        )

        # A problem the node reports of itself is an alert of the station's, with the node's
        # own words, and it closes once the node stops reporting it
        router.succeed("curl -sf -X DELETE http://127.0.0.1:8025/api/v1/messages")
        problem = 'node_problem{key="probe",summary="a probe problem"} 1'
        assert (code := push("/metrics/job/node/instance/pc", body=problem)) == "200", f"the problem's push got {code}"
        assert run_to_end(watch) == "success"
        station.wait_until_succeeds("alert list | grep '^node:pc-probe'", timeout=timedelta(minutes=1))
        router.wait_until_succeeds(
            "curl -s http://127.0.0.1:8025/api/v1/messages | grep -qF '[nixos-station] pc: a probe problem'",
            timeout=timedelta(minutes=1),
        )
        assert (code := push("/metrics/job/node/instance/pc", method="PUT")) == "200", f"the clean push got {code}"
        assert run_to_end(watch) == "success"
        station.wait_until_succeeds("! alert list | grep '^node:pc-probe'", timeout=timedelta(minutes=1))

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

    with subtest("the agent's user on the PC reaches only the resolver, its ports and the printer"):
        guest = "${agent.user}"
        tcp = lambda address, port: f"bash -c 'exec 3<>/dev/tcp/{address}/{port}'"
        pc.succeed("systemd-run --unit=loopback-service ${lib.getExe pkgs.python3} -m http.server --bind :: 8765")
        pc.succeed("systemd-run --unit=loopback-opened ${lib.getExe pkgs.python3} -m http.server --bind :: 8766")
        pc.succeed(
            "systemd-run --unit=loopback-resolver ${lib.getExe pkgs.python3} -c "
            "'import socket, time; server = socket.create_server((\"127.0.0.53\", 53)); time.sleep(1e9)'"
        )
        pc.wait_for_open_port(8765)
        pc.wait_for_open_port(8766)
        pc.wait_for_open_port(53, "127.0.0.53")
        assert pc.succeed(f"id -nG {guest}").split() == [guest], "the agent's user has groups beyond its own"
        # Another unprivileged user, so the refusal is the guest's own and not the service's
        for address in ["127.0.0.1", "192.168.0.102", "[::1]"]:
            pc.succeed(f"runuser -u nobody -- {tcp(address.strip('[]'), 8765)}")
            pc.fail(f"runuser -u {guest} -- timeout 5 {tcp(address.strip('[]'), 8765)}")
            pc.succeed(f"runuser -u {guest} -- timeout 5 {tcp(address.strip('[]'), 8766)}")
        pc.succeed(f"runuser -u {guest} -- timeout 5 {tcp('127.0.0.53', 53)}")
        pc.wait_for_unit("cups.socket")
        pc.succeed(f"runuser -u {guest} -- lpstat -r | grep -qx 'scheduler is running'")
        pc.succeed(f"runuser -l {guest} -c 'command -v gh'")

    with subtest("the agent's user on the PC sees the owner's shares and nothing else of the owner's home"):
        guest = "${agent.user}"
        guest_home = f"/home/{guest}"
        as_guest = lambda command: f"runuser -u {guest} -- sh -c {shlex.quote(command)}"
        for share in ["Projects", "Downloads"]:
            pc.wait_for_unit(pc.succeed(f"systemd-escape --path --suffix=mount {guest_home}/{share}").strip())
        pc.succeed("runuser -u owner -- sh -c 'umask 077; echo kept >~/Projects/private.env; mkdir ~/.ssh; echo key >~/.ssh/id'")
        pc.succeed("runuser -u owner -- sh -c 'umask 022; echo shown >~/Projects/public.txt'")
        # A share the guest only reads shows it what any other user may read, and no more
        pc.succeed(as_guest(f"grep -qx shown {guest_home}/Projects/public.txt"))
        pc.fail(as_guest(f"cat {guest_home}/Projects/private.env"))
        pc.fail(as_guest(f"touch {guest_home}/Projects/new"))
        pc.succeed(as_guest(f"echo made >{guest_home}/Downloads/made"))
        owner = pc.succeed("stat -c %U /home/owner/Downloads/made").strip()
        assert owner == "owner", f"a file the guest made belongs to {owner} on disk"
        pc.fail(as_guest("ls /home/owner"))
        pc.fail(as_guest("cat /home/owner/.ssh/id"))

    with subtest("the agent's user on the PC starts the power units and no other unit"):
        guest = "${agent.user}"
        # polkit answers for an action without running it, so a reboot is judged and not done.
        # Only root may pass it the unit and the verb, so root asks about a process of the guest.
        # pkcheck exits 0 when allowed, 1 when not and 2 when it would ask for a password
        pc.succeed(f"systemd-run --unit=guest-subject -p User={guest} sleep 600")
        subject = pc.succeed("systemctl show -P MainPID guest-subject.service").strip()
        may = lambda unit, verb="start": pc.execute(
            f"${pkgs.polkit.bin}/bin/pkcheck --action-id org.freedesktop.systemd1.manage-units "
            f"--process {subject} --detail unit {unit} --detail verb {verb}"
        )[0]
        for action in ["suspend", "lock", "screen-off", "poweroff", "reboot"]:
            assert may(f"mya-power-{action}.service") == 0, f"the guest may not start {action}"
        for unit, verb in [("mya-power-reboot.service", "stop"), ("cups.service", "start"), ("sshd.service", "restart")]:
            assert may(unit, verb) in (1, 2), f"polkit did not refuse the guest to {verb} {unit}"
        pc.succeed("systemctl stop guest-subject.service")
        # The one unit a test can run: it locks every session, and the PC has none
        pc.succeed(f"runuser -u {guest} -- systemctl start mya-power-lock.service")
        pc.fail(f"runuser -u {guest} -- systemctl restart cups.service")

    with subtest("the PC sleeps, turns off or restarts only while the owner is away"):
        guest = "${agent.user}"
        pc.succeed(f"runuser -l {guest} -c mya-power-idle")
        # A console login is a session of the owner's, in use until its terminal has no input
        pc.wait_until_tty_matches("1", "login: ")
        pc.send_chars("owner\n")
        pc.wait_until_tty_matches("1", "Password: ")
        pc.send_chars("owner\n")
        pc.wait_until_succeeds("loginctl list-sessions | grep -q owner")
        busy = pc.execute(f"runuser -l {guest} -c mya-power-idle")
        assert busy[0] == 1 and "owner is active" in busy[1], busy
        # The unit refuses on its own, so the PC stays up
        pc.fail("systemctl start mya-power-reboot.service")
        # logind marks a console idle only by its own clock and refuses SetIdleHint for it, which
        # hypridle uses on the desktop; the owner leaves instead
        pc.send_chars("exit\n")
        pc.wait_until_succeeds(f"runuser -l {guest} -c mya-power-idle", timeout=timedelta(seconds=30))

    with subtest("no unit is failed"):
        station.succeed("test -z \"$(systemctl list-units --failed --no-legend --all)\"")
  '';
}
