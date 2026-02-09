{
  inputs,
  ...
}:

{
  imports = [
    inputs.nixvim.homeModules.nixvim
    ./hyprland/hyprland-laptop.nix
    ./hyprland/cursor.nix
    ./hyprland/hypridle.nix
    ./hyprland/waybar-laptop.nix
    ./programs/mako.nix
    ./programs/rofi.nix
    ./programs/zsh.nix
    ./programs/git.nix
    ./programs/starship.nix
    ./programs/kitty.nix
    ./programs/btop.nix
    ./programs/nixvim/nixvim.nix
    ./desktop/user-laptop.nix
  ];

  programs.home-manager.enable = true;
  programs.bash.enable = true;
}
