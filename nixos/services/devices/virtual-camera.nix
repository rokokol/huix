{
  config,
  pkgs,
  rokokolName,
  huixDir,
  ...
}:

let
  # Тонкая обёртка над scripts/virtual-cam.sh: кладёт зависимости в PATH.
  # Сама логика (выбор устройства, ffmpeg-режимы) живёт в скрипте.
  virtual-cam = pkgs.writeShellApplication {
    name = "virtual-cam";
    runtimeInputs = with pkgs; [
      ffmpeg
      file
      v4l-utils
    ];
    text = ''
      exec bash "${huixDir}/scripts/virtual-cam.sh" "$@"
    '';
  };
in
{
  # Виртуальная вебка: v4l2loopback создаёт /dev/video10, в который любой
  # источник (ffmpeg, OBS) пишет кадры, а приложения видят его как обычную
  # камеру. Заливка видео/картинки на репите — командой `virtual-cam`.
  boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
  boot.kernelModules = [ "v4l2loopback" ];

  # exclusive_caps=1 нужен, чтобы устройство определялось браузерами/мессенджерами
  # как camera. До появления писателя оно "пустое" и в списке камер не светится —
  # ровно то поведение, что нужно: включаешь заливку → камера появляется.
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=1 video_nr=10 card_label="Virtual Camera" exclusive_caps=1
  '';

  # Команда заливки + v4l2-ctl для диагностики устройства. Команда живёт здесь же,
  # рядом с устройством, к которому она привязана — вся фича в одном модуле.
  environment.systemPackages = [
    virtual-cam
    pkgs.v4l-utils
  ];

  users.users.${rokokolName} = {
    extraGroups = [
      "video"
    ];
  };
}
