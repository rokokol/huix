{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

# The agent and its remote guest accounts share one identity and repository sync policy
let
  cfg = config.rokokol.mya-agent;
  syncName = "mya-agent-sync";
  agentSync = builtins.path {
    name = "agent-sync";
    path = "${inputs.self}/scripts/agent-sync.sh";
  };

  # Clears the guest's rules, before they are made again and when the firewall stops
  guestChain = "mya-agent-guest";
  unguard = ''
    ip46tables -D OUTPUT -o lo -m owner --uid-owner ${cfg.user} -j ${guestChain} 2>/dev/null || true
    ip46tables -F ${guestChain} 2>/dev/null || true
    ip46tables -X ${guestChain} 2>/dev/null || true
  '';

in
{
  options.rokokol.mya-agent = {
    enable = lib.mkEnableOption "the station agent reachable through Telegram";

    guest.enable = lib.mkEnableOption ''
      the session's user without the session, for the agent on another host to log in to over
      SSH. It reaches no service on this host's loopback but the resolver and `loopbackPorts`,
      since such a service trusts every local user, and of the owner's files only `shares`
    '';

    guest.owner = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "The user whose directories `shares` show to the session's user";
    };

    guest.shares = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            path = lib.mkOption {
              type = lib.types.str;
              description = "The owner's directory";
            };
            writable = lib.mkEnableOption "writing to it";
          };
        }
      );
      default = { };
      example = {
        Projects.path = "/home/alice/Projects";
        Downloads = {
          path = "/home/alice/Downloads";
          writable = true;
        };
      };
      description = ''
        The owner's directories the session's user sees, by the path under its home. A share it
        only reads shows what any other user may read there, so a file only the owner may read
        stays closed. In a writable share every file looks like the session user's own, and a
        file it makes is the owner's on disk. The rest of the owner's home stays out of reach
      '';
    };

    guest.loopbackPorts = lib.mkOption {
      type = lib.types.attrsOf lib.types.port;
      default = { };
      example = lib.literalExpression "{ ollama = config.environment.sessionVariables.OLLAMA_PORT; }";
      description = ''
        TCP ports on this host's loopback that the session's user still reaches, by the name of
        what listens there
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "mya";
      description = "The user of the session";
    };

    git.name = lib.mkOption {
      type = lib.types.str;
      default = cfg.user;
      defaultText = lib.literalExpression "config.rokokol.mya-agent.user";
      description = "The name on every commit of the session and of `syncUnit`";
    };

    git.email = lib.mkOption {
      type = lib.types.str;
      example = "agent@example.org";
      description = "The address on every commit of the session and of `syncUnit`";
    };

    home = lib.mkOption {
      type = lib.types.str;
      default = "/home/${cfg.user}";
      defaultText = lib.literalExpression ''"/home/''${user}"'';
      description = "The home of the session's user";
    };

    directories = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        notes = "/srv/notes";
      };
      description = ''
        Directories outside the home that the session edits, by the path of their link inside
        the home. Each is open in the sandbox
      '';
    };

    hiddenPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Paths the session sees empty, each under a read-only tmpfs. A directory in
        `directories` stays open even under one of them
      '';
    };

    repositories = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        dotfiles = "https://github.com/alice/dotfiles";
      };
      description = ''
        Repositories the session works in, by their path under its home. Each is cloned when it
        is missing, and pulled only by `syncUnit` or by the session itself. Its group reads it,
        so the owner can fetch from it
      '';
    };

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Commands the session can run beside the system's, in its user's profile";
    };

    pythonPackages = lib.mkOption {
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = _: [ ];
      defaultText = lib.literalExpression "_: [ ]";
      example = lib.literalExpression "ps: [ ps.matplotlib ]";
      description = "Python libraries that the session's `python3` can import, chosen from its package set";
    };

    extraGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Groups of the session's user, for what its `packages` read";
    };

    syncedBy = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "The user who may start `syncUnit`, as sync.sh does over SSH";
    };

    syncUnit = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      readOnly = true;
      default = if cfg.enable && cfg.repositories != { } then "${syncName}.service" else null;
      defaultText = lib.literalMD "`mya-agent-sync.service`, or null without `repositories`";
      description = ''
        The unit that commits whatever the session left in its `repositories` under the name
        of its user, then rebases each on its upstream. scripts/agent-sync.sh says how
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.enable || cfg.guest.enable) {
      # In the user's profile and not only in the unit's PATH: a shell in the session reads the
      # system's environment again, which drops what the unit adds. These are what the shared
      # skills call: Claude Code reads repositories through git, GitHub through gh
      users.users.${cfg.user} = {
        isNormalUser = true;
        inherit (cfg) home;
        group = cfg.user;
        inherit (cfg) extraGroups;
        packages =
          (with pkgs; [
            curl
            exiftool
            gh
            git
            jq
            (python3.withPackages cfg.pythonPackages)
            trash-cli
          ])
          ++ cfg.packages;
      };
      users.groups.${cfg.user} = { };
    })

    (lib.mkIf cfg.guest.enable {
      # A service on loopback takes every local user for the owner
      networking.firewall.extraCommands = ''
        ${unguard}
        ip46tables -N ${guestChain}
        iptables -A ${guestChain} -d 127.0.0.53,127.0.0.54 -p udp --dport 53 -j RETURN
        iptables -A ${guestChain} -d 127.0.0.53,127.0.0.54 -p tcp --dport 53 -j RETURN
        ${lib.concatMapStrings (port: ''
          ip46tables -A ${guestChain} -p tcp --dport ${toString port} -j RETURN
        '') (lib.attrValues cfg.guest.loopbackPorts)}
        ip46tables -A ${guestChain} -j REJECT
        ip46tables -I OUTPUT -o lo -m owner --uid-owner ${cfg.user} -j ${guestChain}
      '';
      networking.firewall.extraStopCommands = unguard;

      # It has no password, so the login screen would offer a user nobody can log in as
      services.displayManager.sddm.settings.Users.HideUsers = cfg.user;

      assertions = [
        {
          assertion = cfg.guest.shares == { } || cfg.guest.owner != null;
          message = "rokokol.mya-agent.guest.shares needs guest.owner";
        }
      ];

      # A bind mount would need the owner's home open to the guest. bindfs needs no such opening.
      # A writable share maps the owner to the guest and back, so the guest can write and its
      # files stay the owner's. A read-only share maps nothing, so the owner's modes decide
      # exactly as for any other user
      system.fsPackages = lib.optional (cfg.guest.shares != { }) pkgs.bindfs;
      # Mount units and not fileSystems, which a test VM replaces with its own
      systemd.mounts = lib.mapAttrsToList (
        name: share:
        let
          inherit (cfg.guest) owner;
          group = config.users.users.${owner}.group;
        in
        {
          what = share.path;
          where = "${cfg.home}/${name}";
          type = "fuse.bindfs";
          options = if share.writable then "map=${owner}/${cfg.user}:@${group}/@${cfg.user}" else "ro";
          # Wanted and not required, so a share that cannot mount stops no boot
          wantedBy = [ "multi-user.target" ];
          unitConfig.RequiresMountsFor = [ share.path ];
        }
      ) cfg.guest.shares;
    })

    (lib.mkIf cfg.enable {
      users.users.${cfg.user} = {
        # The group passes through to the repositories, and to nothing else the home holds
        homeMode = "710";
      };

      systemd.services.mya-agent-clone = lib.mkIf (cfg.repositories != { }) {
        description = "Clone the repositories the Telegram agent works in";
        wantedBy = [ "hermes-agent.service" ];
        before = [ "hermes-agent.service" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        path = [ pkgs.git ];
        serviceConfig = {
          Type = "oneshot";
          User = cfg.user;
          Group = cfg.user;
          # A host that boots offline clones once the network is there
          Restart = "on-failure";
          RestartSec = "1min";
        };
        script = lib.concatStrings (
          lib.mapAttrsToList (
            dir: url:
            let
              repo = lib.escapeShellArg "${cfg.home}/${dir}";
            in
            ''
              if [ ! -e ${repo}/.git ]; then
                git clone ${lib.escapeShellArg url} ${repo}
              fi
              # The owner fetches through the group, and the agent's sandbox writes with umask
              # 0077: git gives the group read on what it writes, and older files get it here
              git -C ${repo} config core.sharedRepository 0640
              chmod -R g+rX ${repo}/.git
            ''
          ) cfg.repositories
        );
      };

      systemd.services.${syncName} = lib.mkIf (cfg.repositories != { }) {
        description = "Commit what the Telegram agent left in its repositories, and pull them";
        after = [
          "mya-agent-clone.service"
          "network-online.target"
        ];
        wants = [ "network-online.target" ];
        path = [ pkgs.git ];
        # The session's own git config holds the same identity, from the same option; the
        # variables also outrank a user.name that a clone sets for itself
        environment = {
          GIT_AUTHOR_NAME = cfg.git.name;
          GIT_AUTHOR_EMAIL = cfg.git.email;
          GIT_COMMITTER_NAME = cfg.git.name;
          GIT_COMMITTER_EMAIL = cfg.git.email;
        };
        serviceConfig = {
          Type = "oneshot";
          User = cfg.user;
          Group = cfg.user;
          ExecStart = lib.escapeShellArgs (
            [
              (lib.getExe pkgs.bash)
              "${agentSync}"
            ]
            ++ map (dir: "${cfg.home}/${dir}") (lib.attrNames cfg.repositories)
          );
        };
      };

      security.polkit = lib.mkIf (cfg.syncedBy != null && cfg.syncUnit != null) {
        enable = true;
        extraConfig = ''
          // The owner starts the agent's sync unit, and only starts it
          polkit.addRule(function (action, subject) {
            if (action.id == "org.freedesktop.systemd1.manage-units" &&
                subject.user == "${cfg.syncedBy}" &&
                action.lookup("verb") == "start" &&
                action.lookup("unit") == "${cfg.syncUnit}") {
              return polkit.Result.YES;
            }
          });
        '';
      };

      home-manager.users.${cfg.user} = import "${inputs.self}/home-manager/home-mya-agent.nix";

    })
  ];
}
