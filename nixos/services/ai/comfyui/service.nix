{
  config,
  lib,
  pkgs,
  rokokolName,
  ...
}:

let
  cfg = config.rokokol.comfyui;
  dataHome = "/srv/comfyui/.local/share/comfyui";
in
{
  config = lib.mkIf cfg.enable {
    services.comfyui = {
      enable = true;
      user = "comfyui";
      group = "comfyui";
      acceleration = "cuda";
      host = "127.0.0.1";
      home = "/srv/comfyui";
      inherit (cfg) port;
    };

    users.groups.comfyui = { };
    users.users.comfyui.group = "comfyui";
    users.users.${rokokolName}.extraGroups = [ "comfyui" ];

    systemd.services.comfyui.serviceConfig = {
      UMask = lib.mkForce "0007";

      # systemd holds /var/lib/private at 0700 and refuses to start a unit whose StateDirectory
      # sits under a wider mode. The owner then needs root to add a model. /srv/comfyui is
      # created 2770 for the comfyui group instead
      StateDirectory = lib.mkForce [ ];

      # The wrapper copies its source tree into the data directory at every start. Inside a user
      # namespace the real uid is not mapped, so the second start cannot change the mode of the
      # tree the first start made, and the unit fails with EPERM
      PrivateUsers = lib.mkForce false;

      # The copy keeps the read-only modes of the store on a tree that already exists. The
      # service then cannot write into it, so the tree is made writable before every start
      ExecStartPre = [
        "+${pkgs.coreutils}/bin/chmod -R u+rwX ${dataHome}"
      ];
    };
  };
}
