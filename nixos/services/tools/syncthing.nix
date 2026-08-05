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

    openDefaultPorts = true;

    # Additive on purpose: myWiki syncs through the phone, so we must not manage it
    # declaratively — override*=true would prune anything not described here and could
    # break the phone sync. false only ensures the declared bits, prunes nothing. Device
    # IDs are public keys, safe in git; taken from ~/.config/syncthing/config.xml
    overrideDevices = false;
    overrideFolders = false;

    settings.devices = {
      laptop.id = "AHH74UD-KBUQCBR-KY2IC6K-2VS6IIN-RSI2HMT-3MPQIVF-LOHDTCY-3PSSKAM";
      nixos-pc.id = "MNSJ7QK-4YOWUOS-3O5MSOT-UXON7VW-PZFY2YC-34MDG2H-UHTWJ7H-QLTDKQV";
    };

    # Shared Claude Code work/config across both machines (chats, memory, plans, tasks,
    # settings, plugins). On ext4 under ~/.local/share, not on the govno NTFS mount. Only
    # the two PCs — deliberately not the phone. Account cookies stay per-host in
    # claude-profiles/ and are not part of this folder
    settings.folders."claude-shared" = {
      id = "claude-shared";
      path = "${homeDir}/.local/share/claude-shared";
      devices = [ "laptop" "nixos-pc" ];
      type = "sendreceive";
    };
  };

  environment.sessionVariables = {
    SYNCTHING_PORT = port;
  };
}
