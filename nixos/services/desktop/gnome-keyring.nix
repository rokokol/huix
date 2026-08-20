{ ... }:

# Secret Service for libsecret clients — Geary keeps its IMAP passwords here and refuses to
# store them without one. The module wires pam_gnome_keyring into "login", which SDDM's own
# PAM stack substacks, so the keyring unlocks with the login password and never prompts
{
  services.gnome.gnome-keyring.enable = true;
}
