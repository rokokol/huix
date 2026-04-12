{ huixDir, rokokolName, ... }:

let
  homeDir = "/home/${rokokolName}";
  downloadsDir = "${homeDir}/Downloads";
  projectsDir = "${homeDir}/Projects";
  tempDir = "${homeDir}/Temp";
in
{
  imports = [
    ./common-packages.nix
    ./laptop-packages.nix
  ];

  home.stateVersion = "25.11";
  home.file.".face".source = ../../logo.jpg;

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    setSessionVariables = true;

    music = "${homeDir}/Music";
    documents = "${homeDir}/Documents";
    pictures = "${homeDir}/Pictures";
    videos = "${homeDir}/Videos";

    download = downloadsDir;

    desktop = null;
    templates = null;
    publicShare = null;
  };

  gtk = {
    enable = true;
    gtk3.bookmarks = [
      "file://${downloadsDir}/"
      "file://${huixDir}/"
      "file://${tempDir}/"
      "file://${projectsDir}/"
      "file://${homeDir}/myWiki/media/"
      "file:///"
    ];
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    TERMINAL = "kitty";
    BROWSER = "firefox";
    HUIX = huixDir;
  };

  # Directories
  systemd.user.tmpfiles.rules = [
    "d ${projectsDir} 0755 - - -"
    "D ${tempDir} 0777 - - -"
  ];

  # Files
  home.file.".octaverc".text = ''
    PS1('>> ');
    # to disable octave warn
    warning('off', 'Octave:graphics-toolkit-gnuplot');
  '';
}
