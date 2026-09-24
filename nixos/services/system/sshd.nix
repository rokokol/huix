{ rokokolName, ... }:

# Shell access between my machines over the tailnet only. Who may reach port 22 is decided by
# the tailnet policy; this module decides who may log in once connected
{
  services.openssh = {
    enable = true;

    # The port stays closed on LAN and public Wi-Fi: tailscale.nix trusts tailscale0, and that
    # is the only way in. ListenAddress on the tailnet IP is not an option, because sshd starts
    # before tailscaled assigns the address and would fail to bind
    openFirewall = false;

    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ rokokolName ];
    };
  };

  users.users.${rokokolName}.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC8GfEFui86+w9eiayXAsDHkjsOak0C7ZfPWZTbb/DwG nixos-pc"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKwffiOLy9s8L79Tpkj8RQ8E62UQFgVr8sjLMPfiY2pU"
  ];
}
