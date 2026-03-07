{ pkgs, ... }:

{

  services.udev.packages = with pkgs; [
    platformio-core.udev
  ];

  environment.systemPackages = with pkgs; [
    platformio
  ];

  users.users.rokokol = {
    extraGroups = [
      "dialout"
      "input"
    ];
  };
}
