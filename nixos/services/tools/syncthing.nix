{ rokokolName, ... }:

let
  homeDir = "/home/${rokokolName}";
  port = 8384;
in
{
  services.syncthing = {
    enable = true;
    user = rokokolName;
    guiAddress = "127.0.0.1:${toString port}";
    dataDir = "${homeDir}/Documents";
    configDir = "${homeDir}/.config/syncthing";

    overrideDevices = false;
    overrideFolders = false;
  };

  environment.sessionVariables = {
    SYNCTHING_PORT = port;
  };
}
