{
  config,
  lib,
  pkgs,
  huixDir,
  inputs,
  ...
}:

let
  cfg = config.rokokol.sync;
  scriptsDir = "${huixDir}/scripts";
  # A user unit reads none of the session variables, so the sweep targets are passed in here.
  # Taken from the session rather than from commonArgs, so a hand call of sync.sh in a terminal
  # and the unit always sweep the same directories. The alias passes them too: a terminal
  # inherits the session of the last login, which lacks a variable added since
  inherit (config.home.sessionVariables) PROJECTS_DIR SKILLS_DIR SYNC_REMOTES;
  syncEnv = {
    HUIX = huixDir;
    inherit PROJECTS_DIR SKILLS_DIR SYNC_REMOTES;
  };
  syncScript = "${scriptsDir}/sync.sh";

  # Every clone a Telegram agent of this flake keeps, as a remote named after the agent's user
  # and reached by the name of its host
  agentRemotes = lib.concatLists (
    lib.mapAttrsToList (
      hostName: host:
      let
        agent = host.config.rokokol.mya-agent;
      in
      lib.optionals agent.enable (
        lib.mapAttrsToList (dir: origin: {
          name = agent.user;
          inherit origin;
          url = "${hostName}:${agent.home}/${dir}";
          unit = agent.syncUnit;
        }) agent.repositories
      )
    ) inputs.self.nixosConfigurations
  );
  syncDeps = with pkgs; [
    git
    libnotify
    coreutils
    findutils # xargs, which fans the Projects fetches out
    bash
    openssh
  ];
in
{
  options.rokokol.sync = {
    enable = lib.mkEnableOption "the fast-forward of huix, ~/Projects and the skills at login" // {
      default = config.rokokol.workstation.enable;
    };

    remotes = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Name of the remote";
            };
            origin = lib.mkOption {
              type = lib.types.str;
              description = "Origin of the checkouts that get the remote, in any spelling of its URL";
            };
            url = lib.mkOption {
              type = lib.types.str;
              description = "URL of the remote";
            };
            unit = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                A unit on the host before the colon of `url` that commits what the remote's clone
                holds. With one, the commit mode of sync.sh takes the clone's commits into huix
              '';
            };
          };
        }
      );
      default = agentRemotes;
      defaultText = lib.literalMD "every clone of `rokokol.mya-agent.repositories` on each host";
      description = ''
        Remotes that sync.sh adds to every checkout of huix and ~/Projects with the given origin,
        and fetches. Only the commit mode merges, and only into huix from a remote with a `unit`.
        sync.sh removes a remote once it leaves this list
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile."huix/sync-remotes".text = lib.concatMapStrings (
      remote:
      lib.concatStringsSep " " (
        [
          remote.name
          remote.origin
          remote.url
        ]
        ++ lib.optional (remote.unit != null) remote.unit
      )
      + "\n"
    ) cfg.remotes;
    home.sessionVariables.SYNC_REMOTES = "${config.xdg.configHome}/huix/sync-remotes";
    home.shellAliases.syssync = lib.concatStringsSep " " (
      lib.mapAttrsToList (name: value: "${name}=${lib.escapeShellArg value}") syncEnv
      ++ [
        "bash"
        (lib.escapeShellArg syncScript)
      ]
    );

    systemd.user.services = {
      "sync" = {
        Unit = {
          Description = "Fast-forward huix, ~/Projects and the shared skills (sync.sh --pull-only)";
          After = [
            "graphical-session.target"
            "gcr-ssh-agent.service"
          ];
          PartOf = [ "graphical-session.target" ];
          Wants = [ "gcr-ssh-agent.service" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${pkgs.bash}/bin/bash ${syncScript} --pull-only";
          TimeoutStartSec = "2min";
          # gcr's agent prompts on its own and remembers the passphrase, so no SSH_ASKPASS steering
          Environment = [
            "PATH=${lib.makeBinPath syncDeps}"
          ]
          ++ lib.mapAttrsToList (name: value: "${name}=${value}") syncEnv;
        };
        # Runs when the graphical session starts (after boot / login)
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };

    # Runs after every nixos-rebuild: re-trigger the oneshot on the already-up
    # user bus (reloadSystemd has finished → the bus is available)
    home.activation.syncAfterRebuild = lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
      $DRY_RUN_CMD ${pkgs.systemd}/bin/systemctl --user --no-block restart sync.service || true
    '';
  };
}
