{ inputs, ... }:

{
  imports = [
    inputs.nixified-ai.nixosModules.comfyui
    ./access.nix
    ./options.nix
    ./package.nix
    ./service.nix
    ./storage.nix
  ];
}
