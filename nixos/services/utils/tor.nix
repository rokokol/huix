{ pkgs, ... }:

{
  services.tor = {
    enable = true;
    client.enable = true;
    settings = {
      UseBridges = true;
      ClientTransportPlugin = [
        "webtunnel exec ${pkgs.webtunnel}/bin/client"
        "obfs4 exec ${pkgs.obfs4}/bin/obfs4proxy"
      ];
      Bridge = [
        "webtunnel [2001:db8:11d3:d5e7:2939:8453:7baf:868f]:443 531640559965FB7501EB5C006018F61D1E9FA1BB url=https://cdn-34.triplebit.dev/Aec3euCh4ux3deij ver=0.0.2"
        "webtunnel [2001:db8:b1d5:4998:8150:f75b:988f:1f48]:443 216C8BB1C44FC2BFF7AF823B55AC38F113079B93 url=https://cdn-38.triplebit.dev/Bai8aXeiPhar5gai ver=0.0.2"
        "webtunnel [2001:db8:9487:ad3c:96f0:a3d7:faad:1d04]:443 6CE4800062A823AA7EC6E2A9BA95B1A8D0A2B5CE url=https://marmara.ltd/E7NmI7irPfaVamb241KHxc4r ver=0.0.3"
        "webtunnel [2001:db8:4fcd:461f:cbce:edea:fb74:a1e8]:443 F799A0A458365388600F54BD44A99B5887D54911 url=https://wt.aaronstory2026.xyz:2053/vicmackey ver=0.0.4"
        "webtunnel [2001:db8:fbfa:48b4:5520:53e6:24b4:eca0]:443 93807A85521915D7D2BA17725C08AC39035D1741 url=https://web.localenby.is/HmlgNcBbNgRJw862bJVxZRes ver=0.0.3"
        "obfs4 38.242.242.79:27751 03D09C94EC7C562070C54D6D2D58E39996FDE3FD cert=QurHPLyLvn6mu7bgJL52c/sld4COgObhq+jbWQu2pctMwbl1af/aXQw3BqTb0OV7J/58SA iat-mode=0"
        "obfs4 23.26.133.175:8443 F9A3BDE673AFCB9FB835724766A388647A109C6A cert=eBVN+LT2X+2pFGOK0p9a/5MjMmkxF5NiK5Hr9F6NdmOduIZCoRA8QNEjczKPFqd7YX6YQw iat-mode=0"
        "obfs4 193.238.239.50:8443 DDF18E1A90440DA1CB960DA9147CDDFF8D15760B cert=LOfPZwBFcZ1SuXY4PDlBE2PFS1GoAqte1tLD2HU1nk5DWySRrGq5THj+Ya1IcU0SJFDEHg iat-mode=0"
        "obfs4 57.128.45.196:18384 E30D5552BEE79C5E8C61A943E9B3D2949F227C41 cert=boaTbcdp+rFHgUvweiAg60UUUpLZWecGl0uXRU358L/a7ZMrAnS/BodUKM3eyfWC+UVXTg iat-mode=0"
        "obfs4 51.89.228.250:21668 BA8BD67D8898CF378D4F73821DEB5657F4BB98DF cert=bEpLLgOwJ9fOJbeHb5r+ronUF2ck5nRd0Jl3zuy7rLoUp732QK2p/CUHjTAfBPCGfcVtSA iat-mode=0"
      ];
    };
  };
}
