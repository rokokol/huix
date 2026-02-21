{
  description = "I love Monika btw";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";
    nixvim.url = "github:nix-community/nixvim";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-matlab = {
      url = "gitlab:doronbehar/nix-matlab";
      inputs.nixpkgs.follows = "nixpkgs-stable";
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

  outputs =
    {
      nixpkgs,
      nixpkgs-stable,
      home-manager,
      nix-matlab,
      ...
    }@inputs:

    let
      system = "x86_64-linux";

      configCuda = {
        allowUnfree = true;
        cuda.acceptLicense = true;
        cudaSupport = true;
        permittedInsecurePackages = [ ];
      };

      configNoCuda = {
        allowUnfree = true;
        cudaSupport = false;
        permittedInsecurePackages = [ ];
      };

      overlay-stable = final: prev: {
        stable = import nixpkgs-stable {
          inherit system;
          config = configNoCuda;
        };
      };

      overlay-cuda = final: prev: {
        cuda = import nixpkgs {
          inherit system;
          config = configCuda;
        };
      };
    in
    {
      nixosConfigurations.nixos-pc = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs system;
        };
        modules = [
          ./nixos/configuration-pc.nix

          {
            nixpkgs.hostPlatform = system;
            nixpkgs.config = configNoCuda;
            nixpkgs.overlays = [
              overlay-cuda
              nix-matlab.overlay
            ];
          }

          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;

              extraSpecialArgs = { inherit inputs; };

              users.rokokol = import ./home-manager/home-pc.nix;
            };
          }
        ];
      };

      nixosConfigurations.nixos-laptop = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs system;
        };
        modules = [
          ./nixos/configuration-laptop.nix

          {
            nixpkgs.hostPlatform = system;
            nixpkgs.config = configNoCuda;
            nixpkgs.overlays = [
              overlay-stable
            ];
          }

          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;

              extraSpecialArgs = { inherit inputs; };

              users.rokokol = import ./home-manager/home-laptop.nix;
            };
          }
        ];
      };
    };
}
