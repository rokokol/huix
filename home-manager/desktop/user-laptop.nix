{ pkgs, ... }:

{
  home.username = "rokokol";
  home.homeDirectory = "/home/rokokol";
  home.stateVersion = "25.11";
  home.file.".face".source = ../../logo.jpg;

  home.packages = with pkgs; [
    # programs
    ayugram-desktop
    obsidian
    gnome-disk-utility
    celluloid
    gthumb
    file-roller
    octaveFull

    brightnessctl
  ];

  gtk.enable = true;

  home.sessionVariables = {
    NIXPKGS_ALLOW_UNFREE = "1";
    EDITOR = "nvim";
    TERMINAL = "kitty";
    BROWSER = "firefox";
  };

  # Files
  home.file.".octaverc".text = ''
    PS1('>> ');
    # to disable octave warn
    warning('off', 'Octave:graphics-toolkit-gnuplot');
  '';
}
