{
  config,
  lib,
  huixDir,
  ...
}:

{
  config = lib.mkIf config.rokokol.waybar.enable {
    # Swap use alone does not indicate active paging, so it sets no warning colour
    programs.waybar.settings.mainBar."custom/memory" = {
      exec = "${huixDir}/scripts/memory-status.sh status";
      return-type = "json";
      format = "{}";
      interval = 2;
    };
  };
}
