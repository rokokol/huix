{ pkgs, ... }:

{
  services.tor = {
    enable = true;
    client.enable = true;
    settings = {
      UseBridges = true;
      ClientTransportPlugin = "webtunnel exec ${pkgs.webtunnel}/bin/client";
      Bridge = [
        "webtunnel [2001:db8:ff84:4f48:f49f:f168:e6b3:ba74]:443 1A5283F498F3F30FBC36C4D0FA16C34F9E34FEBE url=https://goodwearevday.site/6ac2ad9c5821c1612524189d9d125043cbdee45c ver=0.0.3"
        "webtunnel [2001:db8:8e83:d0ca:d4a8:3fb6:c859:c9fd]:443 5739A92BBDBFFF14CC9DB57D760C5EE7AD4DED71 url=https://wtb006.unshakled.net/ ver=0.0.3"
        "webtunnel [2001:db8:43cc:d277:5ba1:dcd1:516e:d983]:443 AD62C15FAC9C8695F41F4BB5D1F16373F906177F url=https://mitch.pmvl.eu/r9mZqSFwOHSQATtQoPWwZQk9 ver=0.0.1"
        "webtunnel [2001:db8:8ed6:e6c9:5fc9:9f20:a373:2374]:443 1636A2EFFBAA4B162F5FF461A1663EB55C41AE11 url=https://hanoi.delivery/roQFPLtlspWT6yIKeXD6lEci ver=0.0.3"
      ];
    };
  };
}
