{ ... }:

{
  imports = [
    ./ai/comfyui.nix
    ./ai/ollama.nix
    ./ai/openwebui.nix
    ./desktop/amnezia-vpn.nix
    ./desktop/file-manager.nix
    ./desktop/sddm.nix
    ./desktop/ssh-askpass.nix
    ./desktop/throne.nix
    ./devices/printer.nix
    ./devices/tablet.nix
    ./devices/virtual-camera.nix
    ./system/appimage.nix
    ./system/cachix.nix
    ./system/nix-ld.nix
    ./tools/jupyter.nix
    ./tools/libre-translate.nix
    ./tools/searxng.nix
    ./tools/syncthing.nix
    ./utils/docker.nix
    ./utils/embedded.nix
    ./utils/virtualization.nix
  ];
}
