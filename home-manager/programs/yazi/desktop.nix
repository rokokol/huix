{ config, lib, ... }:

# yazi's own desktop file asks for a terminal, and xdg-open cannot provide one, so this entry
# opens it in a kitty window, as nixvim/opener.nix does for nvim. Folders and archives open
# through it, and so does SUPER+E; it only serves as an opener, so the launcher hides it.
# Thunar stays installed but is no longer the default
let
  folders = [
    "application/x-directory"
    "inode/directory"
  ];

  # yazi reveals an archive in its folder, where Space a o, a e and a x take it from there
  archives = [
    "application/gzip"
    "application/vnd.rar"
    "application/x-7z-compressed"
    "application/x-bzip2"
    "application/x-bzip2-compressed-tar"
    "application/x-compressed-tar"
    "application/x-rar"
    "application/x-tar"
    "application/x-xz"
    "application/x-xz-compressed-tar"
    "application/x-zstd-compressed-tar"
    "application/zip"
    "application/zstd"
  ];
in
lib.mkIf config.programs.yazi.enable {
  xdg.desktopEntries.yazi-kitty = {
    name = "Yazi";
    genericName = "File Manager";
    exec = "kitty yazi %F";
    icon = "yazi";
    noDisplay = true;
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = lib.genAttrs (folders ++ archives) (_: "yazi-kitty.desktop");
  };
}
