{ inputs, system, ... }:
# The compositor, its portal and the two plugins come from their flakes, built against
# one Hyprland revision; under the nixpkgs names, so programs.hyprland, the HM module,
# xdg.portal and every script's PATH take them without a line each
_final: prev: {
  inherit (inputs.hyprland.packages.${system}) hyprland xdg-desktop-portal-hyprland;
  hyprlandPlugins = prev.hyprlandPlugins // {
    hyprgrass = inputs.hyprgrass.packages.${system}.default;
    inherit (inputs.hyprland-plugins.packages.${system}) hyprbars;
  };
}
