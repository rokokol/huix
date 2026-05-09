{ ... }:

{
  services.zapret = {
    enable = true;
    params = [
      "--filter-tcp=443 --dpi-desync=fake,split2 --dpi-desync-autottl=2 --dpi-desync-repeats=6 --dpi-desync-fooling=md5sig"
      "--new"
      "--filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=11 --dpi-desync-any-protocol"
    ];
  };

  boot.kernelModules = [
    "nft_queue"
    "nfnetlink_queue"
  ];
}
