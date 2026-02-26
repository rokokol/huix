{ pkgs, inputs, ... }:

{
  imports = [
    inputs.nixvim.homeModules.nixvim
    ./programs/mako.nix
    ./programs/rofi.nix
    ./programs/zsh.nix
    ./programs/git.nix
    ./programs/starship.nix
    ./programs/kitty.nix
    ./programs/btop.nix
    ./programs/direnv.nix
    ./programs/nixvim/nixvim.nix
    ./programs/ssh.nix
    ./desktop/user-pc.nix
  ];

  programs.home-manager.enable = true;
  programs.bash.enable = true;
  _module.args.btopPackage = pkgs.btop-cuda;
}
