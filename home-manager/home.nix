{ config, pkgs, ... }:

{
  imports = [
    ./programs/zsh.nix
    ./programs/git.nix
    ./programs/neovim.nix
    ./programs/starship.nix
    ./programs/kitty.nix
    ./programs/btop.nix
    ./desktop/gnome.nix
    ./desktop/desktop-entries.nix
    ./desktop/user.nix
  ];

  programs.home-manager.enable = true;
  programs.bash.enable = true;
}


