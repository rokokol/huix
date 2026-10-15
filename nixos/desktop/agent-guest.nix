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
  config.rokokol.mya-agent.guest = lib.mkIf config.rokokol.workstation.enable {
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
}
