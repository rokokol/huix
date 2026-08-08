{
  config,
  lib,
  pkgs,
  huixDir,
  ...
}:

# Thin PATH-only wrappers for the scripts that are exposed as commands: the body stays in the live
# checkout, so a script can be edited without a rebuild, while Nix owns the dependency list.
# Everything else in scripts/ is reached by absolute path from hyprland.conf, waybar or a unit
let
  mkScript =
    name:
    {
      runtimeInputs ? [ ],
      env ? { },
    }:
    pkgs.writeShellApplication {
      inherit name runtimeInputs;
      text =
        lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: ''export ${k}="${v}"'') env)
        + ''

          exec bash "${huixDir}/scripts/${name}.sh" "$@"
        '';
    };

  scripts = with pkgs; {
    alarm = {
      runtimeInputs = [
        coreutils
        gawk
        libnotify
        pipewire
        procps
        wireplumber
      ];
      # freedesktop sound theme ships a proper alarm clip; reference it directly
      env.ALARM_SOUND = "${sound-theme-freedesktop}/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga";
    };

    # gnused/gnugrep/procps are for `init`: sed rewrites legacy plugin paths, grep is the
    # leftover-path control check, pgrep -x claude guards against a live session
    claude-account.runtimeInputs = [
      coreutils
      gnugrep
      gnused
      jq
      procps
    ];

    virtual-mic.runtimeInputs = [
      coreutils
      ffmpeg
      pulseaudio
    ];
  };
in
{
  # Exposed so other modules can reference a wrapper's store path (claude.nix's activation hook)
  options.custom.scripts.packages = lib.mkOption {
    type = lib.types.attrsOf lib.types.package;
    readOnly = true;
    default = lib.mapAttrs mkScript scripts;
    description = "PATH wrappers around scripts/*.sh, keyed by command name";
  };

  config.home.packages = lib.attrValues config.custom.scripts.packages;
}
