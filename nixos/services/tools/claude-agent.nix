{
  config,
  lib,
  pkgs,
  inputs,
  rokokolName,
  ...
}:

# Claude Code on the archive host, reachable through a Telegram bot. It runs in tmux as a user of
# its own, so the owner can attach to it and other units can type into it. Syncthing runs as the
# same user, so the session edits the archive's folders and its edits reach every peer. The
# snapshots stay root's and out of its sight
let
  cfg = config.rokokol.claude-agent;
  inherit (config.rokokol.syncthing) archive;
  account = config.home-manager.users.${cfg.user}.programs.claude-account;

  home = "/home/${cfg.user}";
  # The shared state holds absolute paths under the owner's home, as the workstations write
  # them. The session sees its own home under that name too, so those paths resolve
  ownerHome = "/home/${rokokolName}";
  socket = "/run/claude-agent/tmux";
  stateDir = "${home}/.local/state/claude-telegram";
  tmuxCmd = "${lib.getExe pkgs.tmux} -S ${socket}";

  settings = pkgs.writeText "claude-agent-settings.json" (
    builtins.toJSON {
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
    # The owner's direct messages only, so the bot never offers pairing to a stranger. Later
    # changes are the access skill's, and are kept
    if [ ! -e ${stateDir}/access.json ]; then
      ${lib.getExe' pkgs.coreutils "install"} -d -m 0700 ${stateDir}
      ${lib.getExe pkgs.jq} -n --arg id "$(cat "$CREDENTIALS_DIRECTORY/owner-chat-id")" \
        '{dmPolicy: "allowlist", allowFrom: [$id]}' >${stateDir}/access.json
    fi
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
    enable = lib.mkEnableOption "Claude Code reachable through a Telegram bot, editing the archive";

    user = lib.mkOption {
      type = lib.types.str;
      default = "mya";
      description = "The user of the session, and of Syncthing with it";
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

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = archive.enable;
        message = "rokokol.claude-agent needs rokokol.syncthing.archive, whose folders it edits";
      }
    ];

    rokokol.claude-agent.plugins = [
      (builtins.path {
        name = "claude-agent-plugin";
        path = "${inputs.self}/nixos/services/tools/claude-agent-plugin";
      })
    ];

    rokokol.syncthing.archive.editor = cfg.user;

    # In the user's profile and not only in the unit's PATH: a shell in the session reads the
    # system's environment again, which drops what the unit adds. Bun runs the Telegram channel,
    # and Claude Code reads repositories through git
    users.users.${cfg.user} = {
      isNormalUser = true;
      group = cfg.user;
      inherit (cfg) extraGroups;
      packages =
        (with pkgs; [
          bun
          git
          tmux
        ])
        ++ cfg.packages;
    };
    users.groups.${cfg.user} = { };

    home-manager.users.${cfg.user} = import ../../../home-manager/home-claude-agent.nix;

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
        "syncthing.service"
      ];
      # The setuid wrappers, the user's commands and the system's, as in a login shell
      path = [
        "/run/wrappers"
        "/etc/profiles/per-user/${cfg.user}"
        "/run/current-system/sw"
      ];
      environment = {
        HOME = ownerHome;
        CLAUDE_CONFIG_DIR = account.claudeDir;
        TELEGRAM_STATE_DIR = stateDir;
      };
      unitConfig = {
        RequiresMountsFor = lib.attrValues archive.folders;
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
        ExecStart = "${tmuxCmd} new-session -d -s claude -c ${ownerHome} ${lib.escapeShellArg cfg.command}";
        Restart = "always";
        RestartSec = 5;
        RuntimeDirectory = "claude-agent";
        RuntimeDirectoryMode = "0700";
        EnvironmentFile = config.sops.templates."claude-agent.env".path;
        LoadCredential = "owner-chat-id:${config.sops.secrets."telegram-owner-chat-id".path}";

        # Of the archive's volume, the folders alone; of the homes, the session's own, also
        # under the owner's name. Syncthing's key and API key stay out of sight as well. Syncthing
        # runs as the same user, so /proc/PID/root would show its files; the PrivateUsers of the
        # nixpkgs unit is what shuts that path, and the boot test checks it
        ProtectSystem = "strict";
        ProtectHome = "tmpfs";
        PrivateTmp = true;
        TemporaryFileSystem = "${archive.mountPoint}:ro";
        BindPaths = [
          home
          "${home}:${ownerHome}"
        ]
        ++ lib.attrValues archive.folders;
        InaccessiblePaths = [ config.services.syncthing.dataDir ];
      };
    };
  };
}
