{ config, lib, ... }:

# Secret Service for libsecret clients — Geary keeps its IMAP passwords here and refuses to
# store them without one. The module wires pam_gnome_keyring into "login", which SDDM's own
# PAM stack substacks, so the keyring unlocks with the login password and never prompts
{
  options.rokokol.gnome-keyring.enable =
    lib.mkEnableOption "the GNOME keyring as the Secret Service"
    // {
      default = config.rokokol.workstation.enable;
    };

  config = lib.mkIf config.rokokol.gnome-keyring.enable {
    services.gnome.gnome-keyring.enable = true;
  };
}
