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
  options.rokokol.waybar = {
    swap = lib.mkEnableOption "used swap beside used RAM in the memory indicator, red past a threshold";

    swapWarnMb = lib.mkOption {
      type = lib.types.ints.positive;
      default = 500;
      description = "megabytes of swap in use from which the indicator turns red";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.swap) {
    # Replaces waybar's memory module in the hardware group (bar.nix picks which): that
    # module colours by the RAM percentage only and knows no class for the swap
    programs.waybar.settings.mainBar."custom/memory" = {
      exec = "${huixDir}/scripts/memory-status.sh status -w ${toString cfg.swapWarnMb}";
      return-type = "json";
      format = "{}";
      interval = 2;
    };
  };
}
