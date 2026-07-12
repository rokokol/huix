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
  # sync.sh больше не гоняется по таймеру: он запускается на старте графической
  # сессии (загрузка/логин) и после каждого nixos-rebuild (хук активации ниже).
  systemd.user.services = {
    "sync" = {
      Unit = {
        Description = "Синхронизация huix-репозитория с upstream (sync.sh)";
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
      # Запуск при старте графической сессии (после загрузки / логина).
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };

  # Запуск после каждого nixos-rebuild: дёргаем oneshot заново уже поднятой
  # пользовательской шиной (reloadSystemd уже отработал → бас доступен).
  home.activation.syncAfterRebuild = lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
    $DRY_RUN_CMD ${pkgs.systemd}/bin/systemctl --user --no-block restart sync.service || true
  '';
}
