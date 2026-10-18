{ lib, osConfig, ... }:

{
  options.rokokol.workstation.enable =
    lib.mkEnableOption "the desktop session and the GUI programs"
    // {
      default = osConfig.rokokol.workstation.enable;
    };
}
