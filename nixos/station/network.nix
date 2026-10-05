_:

# A fixed address on the wired link and no NetworkManager. The router reserves the same address
# for this MAC, so the host stays reachable on the LAN with or without the reservation. The match
# is the permanent MAC and not the interface name: a kernel or firmware change that renames the
# card must not leave the host with no network. The Wi-Fi card matches nothing and stays down
{
  networking = {
    useDHCP = false;
    useNetworkd = true;
  };

  systemd.network.networks."10-lan" = {
    matchConfig.PermanentMACAddress = "1c:1b:0d:f9:bd:22";
    address = [ "192.168.0.104/24" ];
    routes = [ { Gateway = "192.168.0.1"; } ];
    linkConfig.RequiredForOnline = "routable";

    # The router, the same server the desktops get from DHCP
    dns = [ "192.168.0.1" ];
  };

  # The resolver the desktops run too. While a skvpn profile is up, sing-box registers its TUN
  # with it for every name. Under the guard the TUN takes no names, and they go to the router
  services.resolved.enable = true;
}
