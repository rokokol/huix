{ config, lib, ... }:

let
  cfg = config.custom.waybar;
in
{
  options.custom.waybar.nvidia = lib.mkEnableOption "индикатор NVIDIA GPU через nvidia-smi";

  config = lib.mkIf (cfg.enable && cfg.nvidia) {
    programs.waybar.settings.mainBar."custom/gpu" = {
      # Долгоживущий стрим (nvidia-smi -l 2) вместо форка раз в 2с: одна NVML-сессия,
      # waybar обновляется на каждую строку stdout.
      exec = "nvidia-smi --query-gpu=utilization.gpu,memory.used,temperature.gpu --format=csv,noheader,nounits -l 2 | awk -F', ' '{printf \"%d%% %.1fGB %d°C 📹\\n\", $1, $2/1024, $3; fflush()}'";
      format = "{}";
      tooltip = false;
    };
  };
}
