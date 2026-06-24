{ ... }:

{
  imports = [
    # ./ai/comfyui.nix
    ./ai/ollama.nix
    ./ai/openwebui.nix
    ./desktop/amnezia-vpn.nix
    ./desktop/file-manager.nix
    ./desktop/sddm.nix
    ./desktop/ssh-askpass.nix
    ./desktop/wl-clip-persist.nix
    ./devices/printer.nix
    ./devices/tablet.nix
    ./devices/virtual-camera.nix
    ./system/cachix.nix
    ./system/nix-ld.nix
    ./tools/jupyter.nix
    ./tools/libre-translate.nix
    ./tools/searxng.nix
    ./tools/syncthing.nix
    ./utils/arduino.nix
    ./utils/docker.nix
    ./utils/tor.nix
    ./utils/virtualization.nix
  ];

  custom.jupyter = {
    enable = true;
    withCuda = true;
  };
}
