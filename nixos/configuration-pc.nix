{ pkgs, ... }:

{
  imports = [
    ./default.nix
    ./pc/default.nix
    ./services
  ];

  system.stateVersion = "25.11";
  services.ollama.package = pkgs.stable.ollama-cuda;

  rokokol = {
    jupyter.enable = true;

    comfyui.enable = true;
    openwebui.enable = false;
    searxng.enable = true;

    printer.enable = true;
    tablet.enable = true;
    virtualCamera.enable = true;
    virtualization.enable = true;
  };
}
