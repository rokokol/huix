{
  config,
  lib,
  pkgs,
  ...
}:

# Swap compressed in RAM, used only under memory pressure: it holds cold pages in place of an OOM
# kill. Its priority is above a disk swap's default, so the laptop's partition takes only what
# zram cannot. A default, so a host can stay without swap.
#
# Swap metrics count the pages zram holds at their full size, which says nothing of the RAM it
# takes. mm_stat has both, and a timer writes them for node_exporter wherever zram is on
let
  metrics = pkgs.writeShellApplication {
    name = "zram-metrics";
    runtimeInputs = with pkgs; [ coreutils ];
    text = ''
      out=${config.rokokol.node-exporter.textfileDir}/zram.prom
      tmp=$(mktemp "$out.XXXXXX")
      trap 'rm -f "$tmp"' EXIT
      # Fields of mm_stat, in its order: the data swapped in, its compressed size, and the RAM
      # zram takes for it, overhead included
      metric() {
        printf '# HELP zram_%s %s\n# TYPE zram_%s gauge\n' "$1" "$3" "$1"
        for stat in /sys/block/zram*/mm_stat; do
          [ -r "$stat" ] || continue
          read -r -a fields <"$stat"
          device=''${stat#/sys/block/}
          printf 'zram_%s{device="%s"} %s\n' "$1" "''${device%/mm_stat}" "''${fields[$2]}"
        done
      }
      {
        metric original_bytes 0 "Data swapped into zram, at its full size"
        metric compressed_bytes 1 "Data swapped into zram, compressed"
        metric memory_used_bytes 2 "RAM that zram takes, overhead included"
      } >"$tmp"
      chmod 0644 "$tmp"
      mv "$tmp" "$out"
    '';
    meta.description = "Write the memory use of each zram device for node_exporter";
  };
in
{
  zramSwap.enable = lib.mkDefault true;

  systemd.services.zram-metrics = lib.mkIf config.zramSwap.enable {
    description = "Write the memory use of zram for node_exporter";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe metrics;
      # The timer starts it twice a minute, and the start and the finish are not news
      LogLevelMax = "notice";
      ProtectSystem = "strict";
      ReadWritePaths = [ config.rokokol.node-exporter.textfileDir ];
      ProtectHome = true;
      PrivateNetwork = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };

  systemd.timers.zram-metrics = lib.mkIf config.zramSwap.enable {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "10s";
      OnUnitActiveSec = "30s";
      AccuracySec = "1s";
    };
  };
}
