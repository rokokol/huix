{ ... }:

{
  imports = [
    ./ai/ollama.nix
    ./desktop/amnezia-vpn.nix
    ./desktop/file-manager.nix
    ./desktop/sddm.nix
    ./desktop/ssh-askpass.nix
    ./utils/docker.nix
    ./utils/embedded.nix
    ./utils/tor.nix
    ./desktop/wl-clip-persist.nix
    ./system/appimage.nix
    ./system/cachix.nix
    ./system/nix-ld.nix
    ./tools/libre-translate.nix
    ./tools/syncthing.nix
    ./tools/jupyter.nix
  ];

  custom.jupyter = {
    enable = true;
  };
}
