{ rokokolName, ... }:

# The seam for rokokol/skvpn: enable plus the routing policy. The module already owns the
# CLI with its completions, the sing-box@ template unit, boot restore, the subscription
# sync timer, the sing-box user, the profiles directory, the loose rpfilter and the
# TUN/DNS base — including the bypasses for Tailscale, Docker and Syncthing, which follow
# their services.*.enable by themselves, and the Russia and AI rule-set data, which lives
# in the module's own lock and refreshes with the weekly input bump. Do not add any of
# that back here
{
  services.skvpn = {
    enable = true;

    # `skvpn` alone on the prompt: NOPASSWD sudo for exactly this command plus the alias
    trustedUsers = [ rokokolName ];

    # Russian destinations leave directly: the exit refuses them fail-closed
    direct.russia.enable = true;

    # Torrents leave directly, so the exit's address stays out of swarms: whole for the listed
    # clients, only the sniffed part for any other
    direct.bittorrent.enable = true;

    # With no profile up, AI services are refused rather than reached from a Russian address
    guard.ai.enable = true;

    # DNS-over-TLS through the proxy goes to Quad9 rather than the module's default
    dns.remoteServer = "9.9.9.9";
  };
}
