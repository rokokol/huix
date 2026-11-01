{
  config,
  lib,
  rokokolName,
  ...
}:

# The station's agent logs in to a workstation over SSH, as a guest user of its own. It sees these
# of the owner's directories, and the rest of the owner's home stays out of its reach
let
  home = "/home/${rokokolName}";
  share = writable: name: {
    path = "${home}/${name}";
    inherit writable;
  };
in
{
  config.rokokol.mya-agent = lib.mkIf config.rokokol.workstation.enable {
    # The agent runs the heavy plots here and sends the pictures to the station
    pythonPackages = ps: [ ps.matplotlib ];
    guest = {
      enable = true;
      owner = rokokolName;
      shares =
        lib.genAttrs [ "Projects" ] (share false)
        // lib.genAttrs [
          "Documents"
          "Downloads"
          "Pocket"
        ] (share true);
    };
  };

  # Documents, Downloads and Projects are made by xdg-user-dirs and Pocket has nothing that would
  # make it, while the guest's mount needs it to exist; tmpfiles makes it before that mount starts
  config.systemd.tmpfiles.rules = lib.mkIf config.rokokol.workstation.enable [
    "d ${home}/Pocket 0755 ${rokokolName} ${config.users.users.${rokokolName}.group} -"
  ];
}
