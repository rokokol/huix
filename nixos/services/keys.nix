{ pkgs, ... }:

let
  askpass = pkgs.writeShellScript "rofi-askpass" ''
    ${pkgs.rofi}/bin/rofi -dmenu -password -p "🤫" "$@"
  '';
in
{
  programs.ssh = {
    startAgent = true;
    askPassword = "${askpass}";
    enableAskPassword = true;
  };

  security = {
    polkit.enable = true;
  };

  environment.systemPackages = [ pkgs.rofi ];
}
