{ config, ... }:

# Mesh client for the official Tailscale coordination server. The tailnet is joined once by
# hand (`sudo tailscale up`) — the state lives in /var/lib/tailscale and survives rebuilds
{
  services.tailscale = {
    enable = true;

    # The daemon punches out on its own; this opens the direct UDP path so peers reach it
    # without falling back to a DERP relay
    openFirewall = true;
  };

  # Peers on the tailnet reach services bound on this host, and every one of them is mine
  networking.firewall.trustedInterfaces = [ config.services.tailscale.interfaceName ];
}
