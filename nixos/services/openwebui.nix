{ pkgs, lib, ... }:

{
  services.open-webui = {
    enable = true;
    host = "127.0.0.1";
    port = 8080;

    package = pkgs.open-webui;

    environment = {
      OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";
    };
  };

  users.groups.open-webui = { };
  users.users.open-webui = {
    isSystemUser = true;
    group = "open-webui";
  };

  # 2. Добавляем пользователя rokokol в группу open-webui
  users.users.rokokol.extraGroups = [ "open-webui" ];

  # 3. Переопределяем параметры изоляции systemd-сервиса
  systemd.services.open-webui.serviceConfig = {
    DynamicUser = lib.mkForce false; # Отключаем изоляцию в /var/lib/private
    User = "open-webui";
    Group = "open-webui";
    StateDirectoryMode = "0770"; # Даем полные права владельцу и группе
    UMask = "0007"; # Новые файлы будут создаваться с правами группы (rw-)
  };
}
