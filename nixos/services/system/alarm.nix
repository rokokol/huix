{
  config,
  lib,
  rokokolName,
  ...
}:

let
  cfg = config.custom.alarm;
in
{
  options.custom.alarm.enable =
    lib.mkEnableOption "passwordless rtcwake so the user-session `alarm` script can suspend with an RTC wakeup";

  config = lib.mkIf cfg.enable {
    # The alarm needs to program the RTC and suspend the kernel directly
    # (`rtcwake -m mem`), which requires root. Grant exactly that one binary,
    # by its stable system path, with no password.
    security.sudo.extraRules = [
      {
        users = [ rokokolName ];
        commands = [
          {
            command = "/run/current-system/sw/bin/rtcwake";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };
}
