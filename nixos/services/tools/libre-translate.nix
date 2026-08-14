{ pkgs, ... }:

let
  port = 5000;
  langs = "ru,en";

  # Python env with the libretranslate module — updates the models directly, without starting
  # the server (pkgs.libretranslate ships no dependencyEnv)
  pythonEnv = pkgs.python3.withPackages (ps: [ ps.libretranslate ]);

  updateScript = pkgs.writeShellScript "libretranslate-update-models" ''
    exec ${pythonEnv}/bin/python - <<'EOF'
    from libretranslate.init import check_and_install_models
    check_and_install_models(load_only_lang_codes="${langs}".split(","), update=True)
    EOF
  '';
in
{
  services.libretranslate = {
    enable = true;
    inherit port;
    # Don't update the models at startup: with --update-models the service hangs until the
    # network timeout (~16 min offline). They already sit in /var/lib/libretranslate, and the
    # libretranslate-update-models unit below refreshes them
    updateModels = false;

    extraArgs = {
      "load-only" = langs;
    };
  };

  # Model refresh as its own oneshot unit: weekly by timer, by hand via
  # `sudo systemctl start libretranslate-update-models`. Offline the ExecCondition skips the
  # run quietly (skipped, not failed)
  systemd.services.libretranslate-update-models = {
    description = "Update LibreTranslate language models";
    environment.HOME = "/var/lib/libretranslate";
    serviceConfig = {
      Type = "oneshot";
      User = "libretranslate";
      Group = "libretranslate";
      # Cheap probe: the argos model index is unreachable, so we are offline
      ExecCondition = "${pkgs.curl}/bin/curl -sfm 10 -o /dev/null https://raw.githubusercontent.com/argosopentech/argospm-index/main/index.json";
      ExecStart = updateScript;
      # Restart the server so it picks up the refreshed models
      ExecStartPost = "+${pkgs.systemd}/bin/systemctl try-restart libretranslate.service";
      TimeoutStartSec = "1h";
    };
  };

  systemd.timers.libretranslate-update-models = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      # Catch up a run missed while the laptop was off; with no network at the moment it fires,
      # the attempt is skipped until the next week
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };

  environment.systemPackages = [ pkgs.libretranslate ];

  environment.sessionVariables = {
    LIBRE_TRANSLATE_PORT = port;
  };
}
