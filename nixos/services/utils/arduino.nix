{ pkgs, rokokolName, ... }:

{

  services.udev.packages = with pkgs; [
    platformio-core.udev
  ];

  environment.systemPackages = with pkgs; [
    platformio
  ];

  users.users.${rokokolName} = {
    extraGroups = [
      "dialout"
      "input"
    ];
  };
}
