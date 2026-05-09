{ ... }:

{
  boot.kernelModules = [
    "nft_queue"
    "nfnetlink_queue"
  ];

  networking.enableIPv6 = false;

  services.zapret = {
    enable = false;

    udpSupport = true;
    udpPorts = [ "443" ];

    # blacklist = [
    #   "googlevideo.com"
    #   "youtube.com"
    #   "youtubei.googleapis.com"
    #   "ytimg.com"
    #   "ggpht.com"
    #   "discord.com"
    #   "discordapp.com"
    #   "discordapp.net"
    #   "discord.gg"
    # ];

    params = [
      "--filter-tcp=443 --dpi-desync=fake,split2 --dpi-desync-autottl=2 --dpi-desync-repeats=6 --dpi-desync-fooling=md5sig"
      "--new"
      "--filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=11 --dpi-desync-any-protocol"
    ];
  };
}
