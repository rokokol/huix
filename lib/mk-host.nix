{ commonArgs, nixpkgsConfig }:
# One NixOS system with Home Manager inside it; the host brings its configuration, its home
# and the overlays it wants, and everything else is the same on every host
{
  configuration,
  home,
  overlays,
}:
let
  inherit (commonArgs) inputs rokokolName system;
in
inputs.nixpkgs.lib.nixosSystem {
  specialArgs = commonArgs;
  modules = [
    configuration
    inputs.virtual-media-devices.nixosModules.default
    inputs.skvpn.nixosModules.default
    inputs.telegram-skill.nixosModules.default

    {
      nixpkgs.hostPlatform = system;
      nixpkgs.config = nixpkgsConfig;
      nixpkgs.overlays = overlays;
    }

    inputs.home-manager.nixosModules.home-manager
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "bak";
        sharedModules = [
          inputs.zen-browser.homeModules.default
          inputs.hyprland-screen-shader.homeModules.default
          inputs.rofi-wooordhunt.homeModules.default
          inputs.ddlc-rofi-theme.homeModules.default
          inputs.claude-account.homeModules.default
          inputs.virtual-media-devices.homeModules.default
          inputs.papers-skill.homeModules.default
        ];

        extraSpecialArgs = commonArgs;

        users.${rokokolName} = import home;
      };
    }
  ];
}
