{ pkgs, lib, ... }:

{
  services.open-webui = {
    enable = true;
    host = "127.0.0.1";
    port = 8080;

    package = pkgs.open-webui;

    environment = {
      OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";
    };
  };

  users.groups.open-webui = { };
  users.users.open-webui = {
    isSystemUser = true;
    group = "open-webui";
  };

  users.users.rokokol.extraGroups = [ "open-webui" ];

  systemd.services.open-webui.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = lib.mkForce "open-webui";
    Group = lib.mkForce "open-webui";
    StateDirectoryMode = lib.mkForce "0770";
    UMask = lib.mkForce "0007";
  };

  systemd.services.open-webui-backup = {
    description = "Safe backup of Open WebUI state for Syncthing";
    path = with pkgs; [
      rsync
      coreutils
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "rsync -a --delete /var/lib/private/open-webui/ /home/rokokol/Sync/open-webui-backup/";
      ExecStartPost = "chown -R rokokol:users /home/rokokol/Sync/open-webui-backup/";
    };
  };

  systemd.timers.open-webui-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5m";
      OnUnitActiveSec = "1h";
      Persistent = true;
    };
  };

  systemd.services.open-webui-restore = {
    description = "Restore Open WebUI state from Syncthing before start";
    before = [ "open-webui.service" ];
    wantedBy = [ "open-webui.service" ];

    path = with pkgs; [ rsync ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "rsync -a --update /home/rokokol/Sync/open-webui-backup/ /var/lib/private/open-webui/";
    };
  };
}
