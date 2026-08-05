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
      # /nix/store mtime=1970 → Qt QML cache serves stale theme; disable so greeter picks up changes
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
