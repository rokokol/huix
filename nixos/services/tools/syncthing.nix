{ myWikiDir, rokokolName, ... }:

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

    openDefaultPorts = true;

    overrideDevices = false;
    overrideFolders = false;

    settings.devices = {
      laptop.id = "AHH74UD-KBUQCBR-KY2IC6K-2VS6IIN-RSI2HMT-3MPQIVF-LOHDTCY-3PSSKAM";
      nixos-pc.id = "MNSJ7QK-4YOWUOS-3O5MSOT-UXON7VW-PZFY2YC-34MDG2H-UHTWJ7H-QLTDKQV";
      phone.id = "QAMHANE-X4B6XWI-45LGTZD-AH4BHDX-FHVWOWE-SBEHXO2-JL5TXBK-CBIUAQB";
    };

    # Claude Code shared state (chats, memory, plugins) — ext4, PC-only, no account cookies
    settings.folders."claude-shared" = {
      id = "claude-shared";
      path = "${homeDir}/.local/share/claude-shared";
      devices = [ "laptop" "nixos-pc" ];
      type = "sendreceive";
    };

    settings.folders."myWiki" = {
      id = "3heyc-wgheb";
      path = myWikiDir;
      devices = [ "laptop" "nixos-pc" "phone" ];
      type = "sendreceive";
    };
  };

  environment.sessionVariables = {
    SYNCTHING_PORT = port;
  };
}
