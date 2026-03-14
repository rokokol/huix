{ ... }:

{
  services.syncthing = {
    enable = true;
    user = "rokoko";
    dataDir = "/home/rokoko/Documents";
    configDir = "/home/rokoko/.config/syncthing";

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
