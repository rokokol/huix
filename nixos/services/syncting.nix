{ ... }:

{
  services.syncthing = {
    enable = true;
    user = "rokokol";
    dataDir = "/home/rokokol/Documents";
    configDir = "/home/rokokol/.config/syncthing";

    overrideDevices = true;
    overrideFolders = true;
  };

  # TCP 22000 - data, UDP 21027 - local
  networking.firewall.allowedTCPPorts = [ 22000 ];
  networking.firewall.allowedUDPPorts = [
    21027
    22000
  ];
}
