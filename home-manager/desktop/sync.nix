{
  pkgs,
  lib,
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
        Description = "Sync the huix repository with upstream (sync.sh)";
        After = [
          "graphical-session.target"
          "ssh-agent.service"
        ];
        PartOf = [ "graphical-session.target" ];
        Wants = [ "ssh-agent.service" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash ${scriptsDir}/sync.sh";
        TimeoutStartSec = "2min";
        Environment = [
          "PATH=${lib.makeBinPath syncDeps}"
          "HUIX=${huixDir}"
          "SSH_ASKPASS_REQUIRE=force"
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
