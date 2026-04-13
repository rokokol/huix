{ pkgs, ... }:

let
  restartAmneziaVpn = pkgs.writeShellScript "restart-amnezia-vpn" ''
    set -eu

    sleep 3

    if ! ${pkgs.systemd}/bin/systemctl --quiet is-active AmneziaVPN.service; then
      exit 0
    fi

    ${pkgs.systemd}/bin/systemctl restart AmneziaVPN.service
  '';

  amneziaVpnDispatcher = pkgs.writeShellScript "amnezia-vpn-dispatcher" ''
    set -eu

    iface="''${1-}"
    action="''${2-}"

    case "$iface" in
      ""|lo|amn*|tun*|tap*|wg*|docker*|veth*|virbr*|br-*)
        exit 0
        ;;
    esac

    case "$action" in
      up|dhcp4-change|dhcp6-change|connectivity-change|reapply)
        ;;
      *)
        exit 0
        ;;
    esac

    ${pkgs.systemd}/bin/systemctl start amnezia-vpn-restart.service
  '';
in
{
  programs.amnezia-vpn = {
    enable = true;
    package = pkgs.stable.amnezia-vpn;
  };

  systemd.services.amnezia-vpn-restart = {
    description = "Restart AmneziaVPN after NetworkManager link changes";
    after = [ "NetworkManager.service" ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = restartAmneziaVpn;
    };
  };

  networking.networkmanager.dispatcherScripts = [
    {
      source = amneziaVpnDispatcher;
      type = "basic";
    }
  ];
}
