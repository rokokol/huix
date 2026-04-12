{ rokokolName, ... }:

let
  homeDir = "/home/${rokokolName}";
in
{
  services.syncthing = {
    enable = true;
    user = rokokolName;
    guiAddress = "127.0.0.1:8384";
    dataDir = "${homeDir}/Documents";
    configDir = "${homeDir}/.config/syncthing";

    overrideDevices = false;
    overrideFolders = false;
  };

  # TCP 22000 - data, UDP 21027 - local
  networking.firewall.allowedTCPPorts = [ 22000 ];
  networking.firewall.allowedUDPPorts = [
    21027
    22000
  ];
}
