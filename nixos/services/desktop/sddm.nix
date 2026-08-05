{ pkgs, inputs, ... }:

let
  ddlcTheme = pkgs.callPackage ./sddm-ddlc/theme-package.nix { inherit inputs; };
  sayoriCursors = pkgs.callPackage ./sddm-ddlc/sayori-cursor.nix { inherit inputs; };
in
{
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    wayland.compositor = "kwin";
    theme = "ddlc";

    settings = {
      # The greeter loads the theme via the stable path /run/current-system/…,
      # while all files in /nix/store have mtime=1970 → Qt's QML cache considers
      # the theme unchanged and serves stale compiled QML: edits aren't visible
      # on a real login (in test-mode the path is unique — everything is fresh
      # there). Disable the greeter's on-disk QML cache; it's short-lived and
      # doesn't need one
      General.GreeterEnvironment = "QT_WAYLAND_SHELL_INTEGRATION=layer-shell,QML_DISABLE_DISK_CACHE=1";

      Theme = {
        CursorTheme = "sayori-cursors";
        CursorSize = 32;
      };
    };
  };

  security.pam.services.login.nodelay = true;
  environment.systemPackages = [
    ddlcTheme
    sayoriCursors
  ];
}
