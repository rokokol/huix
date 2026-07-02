{ config, lib, ... }:

let
  cfg = config.custom.waybar;
in
{
  options.custom.waybar.nvidia = lib.mkEnableOption "индикатор NVIDIA GPU через nvidia-smi";

  config = lib.mkIf (cfg.enable && cfg.nvidia) {
    programs.waybar.settings.mainBar."custom/gpu" = {
      exec = "nvidia-smi --query-gpu=utilization.gpu,memory.used,temperature.gpu --format=csv,noheader,nounits | awk -F', ' '{printf \"%d%% %.1fGB %d°C 📹\", $1, $2/1024, $3}'";
      format = "{}";
      interval = 2;
      tooltip = false;
    };
  };
}
