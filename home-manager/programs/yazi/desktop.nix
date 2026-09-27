{
  config,
  lib,
  pkgs,
  ...
}:

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

  # org.freedesktop.FileManager1 is how a browser or Telegram shows a file in its folder. The
  # service runs this with the method and the paths, the file:// taken off and the rest still
  # percent-encoded; gtk-launch takes them back as URIs into the entry below, where yazi opens
  # a folder or reveals a file. ShowItemProperties reveals too
  filemanager1 = pkgs.writeShellScript "yazi-filemanager1" ''
    shift
    uris=()
    for path; do uris+=("file://$path"); done
    exec ${pkgs.gtk3}/bin/gtk-launch yazi-kitty "''${uris[@]}"
  '';
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

  xdg.configFile."org.freedesktop.FileManager1.common/config".text = ''
    cmd=${filemanager1}
  '';

  # The Open and Save dialogs of the programs that ask the portal for one: yazi in a kitty
  # window of its own class, which Hyprland floats at a fixed size. The wrapper runs
  # `$TERMCMD yazi --chooser-file`; saving starts on a file with the suggested name, which
  # yazi can rename before Enter picks it
  xdg.configFile."xdg-desktop-portal-termfilechooser/config".text = ''
    [filechooser]
    cmd=${pkgs.xdg-desktop-portal-termfilechooser}/share/xdg-desktop-portal-termfilechooser/yazi-wrapper.sh
    default_dir=${config.xdg.userDirs.download}
    env=TERMCMD=kitty --class yazi-chooser
  '';

  # Zen asks the portal for its file dialog only when told to
  programs.zen-browser.profiles.default.settings."widget.use-xdg-desktop-portal.file-picker" = 1;

  # Thunar ships a service file for the same name; the bus reads $XDG_DATA_HOME before the
  # system's folders, so this one is started. A running Thunar still holds the name while it
  # runs
  xdg.dataFile."dbus-1/services/org.freedesktop.FileManager1.service".source =
    "${pkgs.org-freedesktop-filemanager1-common}/share/dbus-1/services/org.freedesktop.FileManager1.service";
}
