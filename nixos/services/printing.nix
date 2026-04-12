{ pkgs, rokokolName, ... }:

{
  programs.system-config-printer.enable = true;
  services.printing = {
    enable = true;
    drivers = with pkgs; [
      gutenprint
    ];
  };

  users.users.${rokokolName} = {
    extraGroups = [
      "lp"
      "scanner"
    ];
  };
}
