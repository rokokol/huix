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
}
