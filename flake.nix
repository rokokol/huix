{
  description = "I love Monika btw";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";
    nixvim.url = "github:nix-community/nixvim";
    nixpkgs-crow-old.url = "github:nixos/nixpkgs/nixos-22.05";

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
      nixpkgs-crow-old,
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

      overlay-crow-old = final: prev: {
        crow-old =
          (import nixpkgs-crow-old {
            inherit system;
            config.allowUnfree = true;
          }).crow-translate;
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
              overlay-crow-old
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
              overlay-crow-old
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
