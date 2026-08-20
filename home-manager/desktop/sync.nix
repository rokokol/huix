{
  lib,
  pkgs,
  huixDir,
  ...
}:

let
  scriptsDir = "${huixDir}/scripts";
  syncDeps = with pkgs; [
    git
    libnotify
    coreutils
    bash
    openssh
  ];
in
{
  systemd.user.services = {
    "sync" = {
      Unit = {
        Description = "Fast-forward the huix repository to upstream (sync.sh --pull-only)";
        After = [
          "graphical-session.target"
          "gcr-ssh-agent.service"
        ];
        PartOf = [ "graphical-session.target" ];
        Wants = [ "gcr-ssh-agent.service" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash ${scriptsDir}/sync.sh --pull-only";
        TimeoutStartSec = "2min";
        # gcr's agent prompts on its own and remembers the passphrase, so no SSH_ASKPASS steering
        Environment = [
          "PATH=${lib.makeBinPath syncDeps}"
          "HUIX=${huixDir}"
        ];
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
}
