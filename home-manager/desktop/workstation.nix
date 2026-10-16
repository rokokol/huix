{ lib, osConfig, ... }:

# The user half of the system's umbrella, read across the boundary at this one place: every
# desktop module of a home defaults its own flag to this option, not to the system's. A home
# without the desktop, like the station agent's, imports this file alone
{
  options.rokokol.workstation.enable =
    lib.mkEnableOption "the desktop session and the GUI programs"
    // {
      default = osConfig.rokokol.workstation.enable;
    };
}
