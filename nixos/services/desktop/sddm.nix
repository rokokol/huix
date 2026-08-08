{ inputs, ... }:

{
  imports = [ inputs.ddlc-sddm-theme.nixosModules.default ];

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    wayland.compositor = "kwin";

    # Theme, cursors and the QML-cache workaround come from the module
    ddlc.enable = true;
  };

  security.pam.services.login.nodelay = true;
}
