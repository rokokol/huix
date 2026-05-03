{ pkgs, inputs, ... }:

{
  imports = [
    inputs.nixvim.homeModules.nixvim
    ./hyprland/hyprland-pc.nix
    ./programs/mako.nix
    ./programs/rofi
    ./programs/git.nix
    ./programs/kitty.nix
    ./programs/btop.nix
    ./programs/direnv.nix
    ./programs/nixvim/default.nix
    ./programs/ssh.nix
    ./programs/thunar.nix
    ./programs/zen.nix
    ./desktop/user-pc.nix
  ];

  programs.home-manager.enable = true;
  programs.bash.enable = true;
  _module.args.btopPackage = pkgs.btop-cuda;
}
