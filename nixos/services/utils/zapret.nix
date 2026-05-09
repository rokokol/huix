{ pkgs, ... }:

{
  boot.kernelModules = [
    "nft_queue"
    "nfnetlink_queue"
  ];

  networking.enableIPv6 = false;

  services.zapret = {
    enable = true;
    package = pkgs.zapret;

    udpSupport = true;
    udpPorts = [
      "443"
      "50000:65535"
    ];

    params = [
      "--filter-tcp=80 --dpi-desync=fake,split2 --dpi-desync-autottl=2 --dpi-desync-fooling=md5sig"
      "--new"
      "--filter-tcp=443 --dpi-desync=fake,split2 --dpi-desync-autottl=2 --dpi-desync-repeats=6 --dpi-desync-fooling=badseq --dpi-desync-fake-tls=${pkgs.zapret}/usr/share/zapret/files/fake/tls_clienthello_www_google_com.bin"
      "--new"
      "--filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=6 --dpi-desync-any-protocol --dpi-desync-fake-quic=${pkgs.zapret}/usr/share/zapret/files/fake/quic_initial_www_google_com.bin"
      "--new"
      "--filter-udp=50000:65535 --dpi-desync=fake,tamper --dpi-desync-any-protocol --dpi-desync-repeats=6 --dpi-desync-fake-quic=${pkgs.zapret}/usr/share/zapret/files/fake/quic_initial_www_google_com.bin"
    ];
  };
}
