{
  config,
  lib,
  huixDir,
  ...
}:

let
  cfg = config.rokokol.waybar;
in
{
  options.rokokol.waybar.swap = lib.mkEnableOption "used swap beside used RAM in the memory indicator";

  config = lib.mkIf (cfg.enable && cfg.swap) {
    # Replaces waybar's memory module in the hardware group (bar.nix picks which): that
    # module shows the RAM alone. Nothing colours it: swap in use is not a fault, and the
    # amount says nothing about whether the machine is paging right now
    programs.waybar.settings.mainBar."custom/memory" = {
      exec = "${huixDir}/scripts/memory-status.sh status";
      return-type = "json";
      format = "{}";
      interval = 2;
    };
  };
}
