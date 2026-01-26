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
      # nix-matlab's Nixpkgs input follows Nixpkgs' nixos-unstable branch. However
      # your Nixpkgs revision might not follow the same branch. You'd want to
      # match your Nixpkgs and nix-matlab to ensure fontconfig related
      # compatibility.
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
      pkgs-stable = import nixpkgs-stable {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {

      nixosConfigurations.nixos-pc = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit pkgs-stable inputs system;
        };
        modules = [
          ./nixos/configuration.nix
          ./nixos/hardware-configuration.nix

          {
            nixpkgs.overlays = [ nix-matlab.overlay ];
          }

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;

            home-manager.extraSpecialArgs = { inherit pkgs-stable inputs; };

            home-manager.users.rokokol = import ./home-manager/home.nix;
          }
        ];
      };
    };
}
