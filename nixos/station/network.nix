_:

# A fixed address on the wired link and no NetworkManager. The router reserves the same address
# for this MAC, so the host stays reachable on the LAN with or without the reservation. The link
# gets its name from its permanent MAC, so a firewall rule can name it. The network matches the
# MAC too and not the name: if the rename ever fails, the host keeps its address. The Wi-Fi
# card matches nothing and stays down
let
  mac = "1c:1b:0d:f9:bd:22";
  interface = "lan";
  address = "192.168.0.104/24";
in
{
  # Sites that open to the LAN take its link and its network from here
  rokokol.tailnet-web.lan = { inherit interface address; };

  networking = {
    useDHCP = false;
    useNetworkd = true;
  };

  # udev applies the name when the card appears, so a switch alone does not rename it
  systemd.network.links."10-lan" = {
    matchConfig.PermanentMACAddress = mac;
    linkConfig.Name = interface;
  };

  systemd.network.networks."10-lan" = {
    matchConfig.PermanentMACAddress = mac;
    address = [ address ];
    routes = [ { Gateway = "192.168.0.1"; } ];
    linkConfig.RequiredForOnline = "routable";

    # The router, the same server the desktops get from DHCP
    dns = [ "192.168.0.1" ];
  };

  # The resolver the desktops run too. While a skvpn profile is up, sing-box registers its TUN
  # with it for every name. Under the guard the TUN takes no names, and they go to the router
  services.resolved.enable = true;
}
