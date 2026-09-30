{ inputs, system, ... }:
# The compositor, its portal and the two plugins come from their flakes, built against
# one Hyprland revision; under the nixpkgs names, so programs.hyprland, the HM module,
# xdg.portal and every script's PATH take them without a line each. hyprbars draws its
# button icons with a hard-coded font (see WORKAROUNDS.md)
_final: prev: {
  inherit (inputs.hyprland.packages.${system}) hyprland xdg-desktop-portal-hyprland;
  hyprlandPlugins = prev.hyprlandPlugins // {
    hyprgrass = inputs.hyprgrass.packages.${system}.default;
    hyprbars = inputs.hyprland-plugins.packages.${system}.hyprbars.overrideAttrs (previous: {
      patches = (previous.patches or [ ]) ++ [ ../patches/hyprbars-icon-font.patch ];
    });
  };
}
