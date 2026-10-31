{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.pi-coding-agent;
  ignores = pkgs.writeText "pi-backup-ignores" ''
    !/.stignore-shared
    !/sessions
    !/sessions/**
    !/configs
    !/configs/**
    !/settings.json
    !/keybindings.json
    !/hoster.json
    !/resources.json
    !/pi-usage.json
    **
  '';
in
{
  config = lib.mkIf config.rokokol.pi.enable {
    home.activation.piBackupIgnores = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${pkgs.coreutils}/bin/install -d -m 0700 ${lib.escapeShellArg cfg.configDir}
      ${pkgs.coreutils}/bin/install -m 0600 ${ignores} ${lib.escapeShellArg "${cfg.configDir}/.stignore-shared"}
      target=${lib.escapeShellArg "${cfg.configDir}/.stignore"}
      if [ "$(${pkgs.coreutils}/bin/head -n 1 "$target" 2>/dev/null || true)" != '#include .stignore-shared' ]; then
        temporary="$(${pkgs.coreutils}/bin/mktemp "$target.XXXXXX")"
        printf '%s\n' '#include .stignore-shared' >"$temporary"
        if [ -e "$target" ]; then
          ${pkgs.gnused}/bin/sed '/^#include \.stignore-shared$/d' "$target" >>"$temporary"
        fi
        ${pkgs.coreutils}/bin/mv "$temporary" "$target"
      fi
    '';
  };
}
