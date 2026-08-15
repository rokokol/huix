{ pkgs, rokokolName, ... }:

{
  imports = [
    ./default.nix
    ./pc/default.nix
    ./services
  ];

  system.stateVersion = "25.11";
  services.ollama.package = pkgs.stable.ollama-cuda;

  services.virtual-media-devices.camera = {
    enable = true;
    users = [ rokokolName ];
  };

  rokokol = {
    searxng.enable = true;

    printer.enable = true;
    tablet.enable = true;
    virtualization.enable = true;
  };
}
