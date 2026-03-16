{ pkgs, ... }:

let
  askpass = pkgs.writeShellScript "rofi-askpass" ''
    ${pkgs.rofi}/bin/rofi -dmenu -password -p "🤫" "$@"
  '';
in
{
  programs.ssh = {
    startAgent = true;
    # askPassword = "${askpass}";
    askPassword = "${pkgs.rofi-pass-wayland}";
    enableAskPassword = true;
  };

  security = {
    polkit.enable = true;
  };

  environment.systemPackages = [ pkgs.rofi ];
}
