{ inputs, ... }:

{
  imports = [
    inputs.nixvim.homeModules.nixvim
    ./programs/zsh.nix
    ./programs/git.nix
    ./programs/neovim.nix
    ./programs/starship.nix
    ./programs/kitty.nix
    ./programs/btop.nix
    ./programs/nixvim/nixvim.nix
    ./desktop/gnome.nix
    ./desktop/user.nix
  ];

  programs.home-manager.enable = true;
  programs.bash.enable = true;
}
