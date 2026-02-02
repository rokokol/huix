{
  description = "I love Monika btw";

  inputs = {

    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-matlab = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "gitlab:doronbehar/nix-matlab";
    };

    freesmlauncher = {
      url = "github:FreesmTeam/FreesmLauncher";
      inputs = {
        nixpkgs = {
          follows = "nixpkgs";
        };
      };
    };
  };

  outputs = { self, nixpkgs, nixpkgs-stable, home-manager, nix-matlab, freesmlauncher, ... }@inputs:

    let
      system = "x86_64-linux";

      config = {
        allowUnfree = true;
        cuda.acceptLicense = true;
        permittedInsecurePackages = [ ];
      };

      overlay-stable = final: prev: {
        stable = import nixpkgs-stable {
          inherit system;
          config = config;
        };
      };
    in
    {

      nixosConfigurations.nixos-pc = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs system;
        };
        modules = [
          ./nixos/configuration.nix
          ./nixos/hardware-configuration.nix

          {
            nixpkgs.hostPlatform = system;
            nixpkgs.config = config;
            nixpkgs.overlays = [
              overlay-stable
              nix-matlab.overlay
            ];
          }

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;

            home-manager.extraSpecialArgs = { inherit inputs; };

            home-manager.users.rokokol = import ./home-manager/home.nix;
          }
        ];
      };
    };
}
