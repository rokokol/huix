{ pkgs, ... }:

let
  port = 5000;
  langs = "ru,en";

  # python-окружение с модулем libretranslate — обновляет модели напрямую,
  # без запуска сервера (у pkgs.libretranslate нет dependencyEnv)
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
    port = port;
    # не обновлять модели при старте: с --update-models сервис висит до сетевого
    # таймаута (~16 мин оффлайн); модели уже лежат в /var/lib/libretranslate,
    # обновлением занимается юнит libretranslate-update-models ниже
    updateModels = false;

    extraArgs = {
      "load-only" = langs;
    };
  };

  # обновление моделей отдельным oneshot-юнитом: по таймеру раз в неделю,
  # вручную — `sudo systemctl start libretranslate-update-models`;
  # без сети ExecCondition тихо пропускает запуск (skipped, не failed)
  systemd.services.libretranslate-update-models = {
    description = "Update LibreTranslate language models";
    environment.HOME = "/var/lib/libretranslate";
    serviceConfig = {
      Type = "oneshot";
      User = "libretranslate";
      Group = "libretranslate";
      # быстрый чек: индекс моделей argos недоступен — значит, мы оффлайн
      ExecCondition = "${pkgs.curl}/bin/curl -sfm 10 -o /dev/null https://raw.githubusercontent.com/argosopentech/argospm-index/main/index.json";
      ExecStart = updateScript;
      # перезапустить сервер, чтобы он подхватил обновлённые модели
      ExecStartPost = "+${pkgs.systemd}/bin/systemctl try-restart libretranslate.service";
      TimeoutStartSec = "1h";
    };
  };

  systemd.timers.libretranslate-update-models = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      # догнать пропущенный по выключенному ноутбуку запуск; учтите: если в момент
      # срабатывания сети нет, попытка пропускается до следующей недели
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };

  environment.systemPackages = [ pkgs.libretranslate ];

  environment.sessionVariables = {
    LIBRE_TRANSLATE_PORT = port;
  };
}
