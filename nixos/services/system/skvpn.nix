{ rokokolName, ... }:

# The seam for rokokol/skvpn: enable plus the routing policy. The module already owns the
# CLI with its completions, the sing-box@ template unit, boot restore, the subscription
# sync timer, the sing-box user, the profiles directory, the loose rpfilter and the
# TUN/DNS base — including the tailnet exclusion, which follows services.tailscale.enable
# by itself, and the Russia rule-set data, which lives in the module's own lock and
# refreshes with the weekly input bump. Do not add any of that back here
{
  services.skvpn = {
    enable = true;

    # `skvpn` alone on the prompt: NOPASSWD sudo for exactly this command plus the alias
    trustedUsers = [ rokokolName ];

    # Russian destinations leave directly: the exit refuses them fail-closed
    direct.russia.enable = true;
  };
}
