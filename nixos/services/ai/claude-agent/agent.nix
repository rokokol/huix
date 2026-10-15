{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

# Claude Code reachable through a Telegram bot. It runs in tmux as a user of its own, so the
# owner can attach to it and other units can type into it. The host says which directories the
# session works in and which paths it must not see
let
  cfg = config.rokokol.claude-agent;
  account = config.home-manager.users.${cfg.user}.programs.claude-account;

  # The directory the session works in, and a path under the home as the session names it
  sessionHome = if cfg.homeAlias != null then cfg.homeAlias else cfg.home;
  inSession = path: sessionHome + lib.removePrefix cfg.home path;
  socket = "/run/claude-agent/tmux";
  stateDir = "${cfg.home}/.local/state/claude-telegram";
  tmuxCmd = "${lib.getExe pkgs.tmux} -S ${socket}";

  # How a reply has to look in Telegram. In the system prompt once a session, rather than in
  # a hook that would repeat it in every turn and on every host
  prompt = ./prompt.md;

  settings = pkgs.writeText "claude-agent-settings.json" (
    builtins.toJSON {
      # Fewer of the subscription's tokens than the shared settings' model; this file outranks it
      model = "sonnet";
      permissions = {
        # The home's links lead there, and Claude Code judges a file by the path it resolves to
        additionalDirectories = lib.attrValues cfg.directories;
        # The sandbox decides what the session can read; a question about it would wait for an
        # answer in Telegram
        allow = [ "Read(//**)" ];
      };
      enabledPlugins = {
        # The owner keeps it on the workstations only
        "cc-plugin-you-should-know@builtin" = false;
        "telegram@claude-plugins-official" = true;
      };
    }
  );

  setup = pkgs.writeShellScript "claude-agent-setup" ''
    set -eu
    # A profile the first time only; which one is active later is the owner's choice
    if [ ! -L ${account.claudeDir} ]; then
      if [ ! -d ${account.profilesDir}/agent ]; then
        ${lib.getExe account.package} add agent
      fi
      ${lib.getExe account.package} use agent
    fi
    # The directory the session works in is trusted, so no session waits on the question. Claude
    # Code keeps no answer given for a home directory, so the question came back each time. The
    # file is there from the first login on
    conf=${account.claudeDir}/.claude.json
    if [ -e "$conf" ]; then
      ${lib.getExe pkgs.jq} --arg dir ${sessionHome} '.projects[$dir].hasTrustDialogAccepted = true' \
        "$conf" >"$conf.tmp"
      mv "$conf.tmp" "$conf"
    fi
    # The owner's direct messages only, so the bot never offers pairing to a stranger. Later
    # changes are the access skill's, and are kept
    if [ ! -e ${stateDir}/access.json ]; then
      ${lib.getExe' pkgs.coreutils "install"} -d -m 0700 ${stateDir}
      ${lib.getExe pkgs.jq} -n --arg id "$(cat "$CREDENTIALS_DIRECTORY/owner-chat-id")" \
        '{dmPolicy: "allowlist", allowFrom: [$id]}' >${stateDir}/access.json
    fi
  '';

  # Clears the guest's rules, before they are made again and when the firewall stops
  guestChain = "claude-agent-guest";
  unguard = ''
    ip46tables -D OUTPUT -o lo -m owner --uid-owner ${cfg.user} -j ${guestChain} 2>/dev/null || true
    ip46tables -F ${guestChain} 2>/dev/null || true
    ip46tables -X ${guestChain} 2>/dev/null || true
  '';

  notify = pkgs.writeShellApplication {
    name = "claude-agent-notify";
    runtimeInputs = with pkgs; [ util-linux ];
    text = ''
      if [ $# -eq 0 ]; then
        echo "usage: claude-agent-notify TEXT..." >&2
        exit 2
      fi
      # A line break would send the text in parts, as an Enter does
      text=$(printf '%s' "$*" | tr '\n' ' ')
      as_agent() { runuser -u ${cfg.user} -- "$@"; }
      # Literal, so that tmux reads no key name or command separator in the text
      as_agent ${tmuxCmd} send-keys -t claude -l -- "$text"
      # A pause, so that the session takes the text as typed before the Enter submits it
      sleep 0.5
      as_agent ${tmuxCmd} send-keys -t claude Enter
    '';
  };
in
{
  options.rokokol.claude-agent = {
    enable = lib.mkEnableOption "Claude Code reachable through a Telegram bot";

    guest.enable = lib.mkEnableOption ''
      the session's user without the session, for the agent on another host to log in to over
      SSH. It reaches no service on this host's loopback but the resolver and `loopbackPorts`, since such a
      service trusts every local user
    '';

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

    home = lib.mkOption {
      type = lib.types.str;
      default = "/home/${cfg.user}";
      defaultText = lib.literalExpression ''"/home/''${user}"'';
      description = "The home of the session's user";
    };

    homeAlias = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/home/alice";
      description = ''
        A second path the session sees its home under, and works in. It hides whatever is
        there on the host. It lets shared state that holds absolute paths from another host
        resolve here
      '';
    };

    directories = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        notes = "/srv/notes";
      };
      description = ''
        Directories outside the home that the session edits, by the path of their link inside
        the home. Each is open in the sandbox, and Claude Code takes it as its own
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

    command = lib.mkOption {
      type = lib.types.str;
      default = lib.escapeShellArgs (
        [
          (lib.getExe pkgs.claude-code)
          "--channels"
          "plugin:telegram@claude-plugins-official"
          "--permission-mode"
          "auto"
          "--settings"
          "${settings}"
          "--append-system-prompt-file"
          "${prompt}"
        ]
        ++ lib.concatMap (plugin: [
          "--plugin-dir"
          "${plugin}"
        ]) cfg.plugins
      );
      defaultText = lib.literalMD "Claude Code with the Telegram channel, in auto mode, with `plugins`";
      description = ''
        The command the session runs. When it ends, a new session starts. A test replaces it,
        because Claude Code needs a login
      '';
    };

    plugins = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = "Claude Code plugin directories that only this session loads";
    };

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Commands the session can run beside the system's, in its user's profile";
    };

    extraGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Groups of the session's user, for what its `packages` read";
    };

    notify = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      readOnly = true;
      default = if cfg.enable then lib.getExe notify else null;
      defaultText = lib.literalMD "`claude-agent-notify`, or null when the agent is off";
      description = ''
        A command that types its arguments into the session as one line and submits them, as
        the owner would. Only root can run it
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
            python3
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
    })

    (lib.mkIf cfg.enable {
      rokokol.claude-agent.plugins = [
        (builtins.path {
          name = "claude-agent-plugin";
          path = "${inputs.self}/nixos/services/ai/claude-agent/plugin";
        })
      ];

      # Bun runs the Telegram channel, and the owner attaches to the session through tmux
      users.users.${cfg.user}.packages = with pkgs; [
        bun
        tmux
      ];

      home-manager.users.${cfg.user} = import "${inputs.self}/home-manager/home-claude-agent.nix";

      sops.secrets."telegram-bot-token" = { };
      sops.secrets."telegram-owner-chat-id" = { };
      sops.templates."claude-agent.env".content = ''
        TELEGRAM_BOT_TOKEN=${config.sops.placeholder."telegram-bot-token"}
      '';

      systemd.services.claude-agent = {
        description = "Claude Code reachable through Telegram";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [
          "network-online.target"
          "home-manager-${cfg.user}.service"
        ];
        # The user's commands and the system's, as in a login shell. The setuid wrappers are left
        # out, since nothing in the session may raise its privileges
        path = [
          "/etc/profiles/per-user/${cfg.user}"
          "/run/current-system/sw"
        ];
        environment = {
          HOME = sessionHome;
          # What Claude Code writes into the shared state names the paths the session uses
          CLAUDE_CONFIG_DIR = inSession account.claudeDir;
          TELEGRAM_STATE_DIR = stateDir;
        };
        unitConfig = {
          RequiresMountsFor = lib.attrValues cfg.directories;
          # Before the shared state arrives, making a profile would put an empty settings.json
          # there, which could win over the workstations' own
          ConditionPathExists = "${account.sharedDir}/settings.json";
        };
        serviceConfig = {
          User = cfg.user;
          Group = cfg.user;
          # tmux leaves a server behind. It ends with the command, and then systemd starts anew
          Type = "forking";
          ExecStartPre = setup;
          ExecStart = "${tmuxCmd} new-session -d -s claude -c ${sessionHome} ${lib.escapeShellArg cfg.command}";
          Restart = "always";
          RestartSec = 5;
          RuntimeDirectory = "claude-agent";
          RuntimeDirectoryMode = "0700";
          EnvironmentFile = config.sops.templates."claude-agent.env".path;
          LoadCredential = "owner-chat-id:${config.sops.secrets."telegram-owner-chat-id".path}";

          # Of the homes, the session's own alone, also under its alias
          ProtectSystem = "strict";
          ProtectHome = "tmpfs";
          PrivateTmp = true;
          TemporaryFileSystem = map (path: "${path}:ro") cfg.hiddenPaths;
          BindPaths = [
            cfg.home
          ]
          ++ lib.optional (cfg.homeAlias != null) "${cfg.home}:${cfg.homeAlias}"
          ++ lib.attrValues cfg.directories;
          # No setuid program raises the session's privileges. A sudo it tries ends at once, and
          # mails root nothing about the timestamp it cannot write under the read-only /run
          NoNewPrivileges = true;
        };
      };
    })
  ];
}
