{ pkgs, ... }:

{
  programs.ssh = {
    startAgent = true;
    askPassword = "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";
    enableAskPassword = true;
  };

  security = {
    polkit.enable = true;
  };

  environment.systemPackages = [ pkgs.kdePackages.ksshaskpass ];
}
