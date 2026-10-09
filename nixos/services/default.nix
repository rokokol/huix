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
    ./devices/sensors.nix
    ./devices/tablet.nix
    ./devices/vial.nix
    ./system/alert-mail.nix
    ./system/appimage.nix
    ./system/backup-heartbeat.nix
    ./system/cachix.nix
    ./system/nix-ld.nix
    ./system/restic-server.nix
    ./system/skvpn.nix
    ./system/smartd.nix
    ./system/sops.nix
    ./system/tailnet-web.nix
    ./system/tailscale.nix
    ./tools/forgejo-mirrors.nix
    ./tools/forgejo.nix
    ./tools/libre-translate.nix
    ./tools/paper-search.nix
    ./tools/searxng.nix
    ./tools/syncthing.nix
    ./tools/telegram-agent.nix
    ./utils/docker.nix
    ./utils/embedded.nix
    ./utils/virtualization.nix
  ];
}
