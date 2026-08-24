{ ... }:

{
  imports = [
    ./ai/ollama.nix
    ./desktop/amnezia-vpn.nix
    ./desktop/file-manager.nix
    ./desktop/gnome-keyring.nix
    ./desktop/sddm.nix
    ./desktop/ssh-agent.nix
    ./devices/printer.nix
    ./devices/tablet.nix
    ./system/appimage.nix
    ./system/cachix.nix
    ./system/nix-ld.nix
    ./system/sing-box.nix
    ./system/sops.nix
    ./system/tailscale.nix
    ./tools/libre-translate.nix
    ./tools/searxng.nix
    ./tools/syncthing.nix
    ./utils/docker.nix
    ./utils/embedded.nix
    ./utils/virtualization.nix
  ];
}
