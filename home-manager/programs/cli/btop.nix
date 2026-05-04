{ pkgs, btopPackage, ... }:

{
  programs.btop = {
    enable = true;
    package = btopPackage;

    settings = {
      color_theme = "gruvbox_dark";
      cuda_support = true;
      rocm_support = false;
      vim_keys = true;
    };
  };
}
