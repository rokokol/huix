{ pkgs, ... }:

{
  boot.kernelModules = [
    "nft_queue"
    "nfnetlink_queue"
  ];

  networking.enableIPv6 = false;

  # Дропаем UDP/443 на уровне системы, чтобы 100% форсировать TLS (TCP)
  networking.firewall.extraCommands = ''
    iptables -I OUTPUT -p udp --dport 443 -j REJECT
  '';

  services.zapret = {
    enable = true;
    package = pkgs.zapret;

    # Отключаем UDP в самом zapret
    udpSupport = false;

    # Пробуем syndata (эффективнее на многих ТСПУ) и фиксированный TTL (если нужно - раскомментировать)
    params = [
      "--filter-tcp=80 --dpi-desync=fake,syndata --dpi-desync-fooling=md5sig"
      "--new"
      "--filter-tcp=443 --dpi-desync=fake,syndata --dpi-desync-repeats=6 --dpi-desync-fooling=badseq --dpi-desync-fake-tls=${pkgs.zapret}/usr/share/zapret/files/fake/tls_clienthello_www_google_com.bin"
      # Если syndata не сработает, попробуй добавить фиксированный TTL:
      # "--filter-tcp=443 --dpi-desync=fake,split2 --dpi-desync-ttl=3 --dpi-desync-repeats=6 --dpi-desync-fooling=badseq --dpi-desync-fake-tls=${pkgs.zapret}/usr/share/zapret/files/fake/tls_clienthello_www_google_com.bin"
    ];
  };
}
