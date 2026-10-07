{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.rokokol.vial.enable = lib.mkEnableOption "user access to Vial keyboards" // {
    default = config.rokokol.workstation.enable;
  };

  # The uaccess tag gives an ACL only when it is set before 73-seat-late.rules runs. extraRules
  # goes to 99-local.rules, which is too late, so the rule is a package with a lower number
  config = lib.mkIf config.rokokol.vial.enable {
    services.udev.packages = [
      (pkgs.writeTextDir "lib/udev/rules.d/70-vial.rules" ''
        KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{serial}=="*vial:*", MODE="0660", TAG+="uaccess"
      '')
    ];
  };
}
