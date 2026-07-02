{ pkgs, ... }:

{
  imports = [
    ./default.nix
    ./pc/default.nix
    ./services
  ];

  system.stateVersion = "25.11";
  services.ollama.package = pkgs.ollama-cuda;

  custom = {
    jupyter = {
      enable = true;
      withCuda = true;
    };

    comfyui.enable = true;
    openwebui.enable = true;
    searxng.enable = true;

    printer.enable = true;
    tablet.enable = true;
    virtualCamera.enable = true;
    virtualization.enable = true;
  };
}
