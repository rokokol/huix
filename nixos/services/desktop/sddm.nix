{
  config,
  lib,
  inputs,
  ...
}:

{
  imports = [ inputs.ddlc-sddm-theme.nixosModules.default ];

  options.rokokol.sddm.enable = lib.mkEnableOption "the SDDM login screen" // {
    default = config.rokokol.workstation.enable;
  };

  config = lib.mkIf config.rokokol.sddm.enable {
    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
      wayland.compositor = "kwin";
    };

    # Theme, cursors and the QML-cache workaround come from the module
    ddlc.sddm.enable = true;

    security.pam.services.login.nodelay = true;
  };
}
