{ config, lib, ... }:

let
  cfg = config.rokokol.waybar;
in
{
  options.rokokol.waybar.nvidia = lib.mkEnableOption "NVIDIA GPU indicator via nvidia-smi";

  config = lib.mkIf (cfg.enable && cfg.nvidia) {
    programs.waybar.settings.mainBar."custom/gpu" = {
      # A long-lived stream (nvidia-smi -l 2) instead of forking every 2s: one NVML
      # session, waybar updates on each stdout line
      exec = "nvidia-smi --query-gpu=utilization.gpu,memory.used,temperature.gpu --format=csv,noheader,nounits -l 2 | awk -F', ' '{printf \"%d%% %.1fGB %d°C 📹\\n\", $1, $2/1024, $3; fflush()}'";
      format = "{}";
      tooltip = false;
    };
  };
}
