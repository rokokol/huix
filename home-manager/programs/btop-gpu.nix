{ pkgs, ... }:

{
  programs.btop = {
    enable = true;
    package = pkgs.btop-cuda;

    settings = {
      color_theme = "gruvbox_dark";
      cuda_support = true;
      rocm_support = false;
      vim_keys = true;
    };
  };
}
