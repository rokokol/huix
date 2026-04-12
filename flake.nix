{
  description = "I love Monika btw";

  # nixConfig = {
  #   extra-substituters = [
  #     "https://cache.nixos.org"
  #     "https://comfyui.cachix.org"
  #     "https://cuda-maintainers.cachix.org"
  #     "https://nix-community.cachix.org"
  #   ];
  #   extra-trusted-public-keys = [
  #     "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
  #     "comfyui.cachix.org-1:33mf9VzoIjzVbp0zwj+fT51HG0y31ZTK3nzYZAX0rec="
  #     "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
  #     "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
  #   ];
  # };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";
    nixvim.url = "github:nix-community/nixvim";

    comfyui-nix.url = "https://flakehub.com/f/utensils/comfyui/0.18.2";

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
      comfyui-nix,
      ...
    }@inputs:

    let
      system = "x86_64-linux";
      rokokolName = "rokokol";
      huixDir = "/home/${rokokolName}/huix";
      govnoDir = "/home/${rokokolName}/govno";

      commonArgs = {
        inherit
          govnoDir
          huixDir
          inputs
          rokokolName
          system
          ;
      };

      configCuda = {
        allowUnfree = true;
        cuda.acceptLicense = true;
        cudaSupport = true;
        cudaCapabilities = [ "8.6" ];
        permittedInsecurePackages = [ ];
      };

      configNoCuda = {
        allowUnfree = true;
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
        specialArgs = commonArgs;
        modules = [
          ./nixos/configuration-pc.nix

          {
            nixpkgs.hostPlatform = system;
            nixpkgs.config = configNoCuda;
            nixpkgs.overlays = [
              overlay-cuda
              overlay-stable
              nix-matlab.overlay
              comfyui-nix.overlays.default
            ];
          }

          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "bak";

              extraSpecialArgs = commonArgs;

              users.${rokokolName} = import ./home-manager/home-pc.nix;
            };
          }
        ];
      };

      nixosConfigurations.nixos-laptop = nixpkgs.lib.nixosSystem {
        specialArgs = commonArgs;
        modules = [
          ./nixos/configuration-laptop.nix

          {
            nixpkgs.hostPlatform = system;
            nixpkgs.config = configNoCuda;
            nixpkgs.overlays = [
              overlay-stable
              nix-matlab.overlay
            ];
          }

          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "bak";

              extraSpecialArgs = commonArgs;

              users.${rokokolName} = import ./home-manager/home-laptop.nix;
            };
          }
        ];
      };
    };
}
