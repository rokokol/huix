{ ... }:

{
  imports = [
    ./ai/ollama.nix
    ./desktop/amnezia-vpn.nix
    ./desktop/file-manager.nix
    ./desktop/sddm.nix
    ./desktop/ssh-askpass.nix
    ./desktop/wl-clip-persist.nix
    ./system/cachix.nix
    ./tools/jupyter.nix
    ./tools/libre-translate.nix
    ./tools/syncthing.nix
    ./utils/docker.nix
    ./utils/tor.nix
  ];
}
