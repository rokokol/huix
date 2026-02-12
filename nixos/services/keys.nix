{ pkgs, ... }:

{
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;
  programs.ssh.startAgent = false;
  environment.systemPackages = with pkgs; [
    seahorse
    gnome-keyring
    gcr
    libsecret
  ];
}
