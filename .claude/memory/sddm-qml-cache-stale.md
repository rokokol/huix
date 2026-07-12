---
name: sddm-qml-cache-stale
description: SDDM DDLC-тема не обновляется на реальном логине из-за дискового QML-кэша Qt + mtime=1970 в nix store
metadata: 
  node_type: memory
  type: project
  originSessionId: 09d9bd5e-960e-4fb6-a599-9891e5fc0764
---

Правки QML-темы SDDM (`nixos/services/desktop/sddm-ddlc/theme/`) собираются и деплоятся
корректно, но на **реальном экране входа** не появляются — виден старый плейсхолдер и старые
баги. При этом `sddm-greeter-qt6 --test-mode --theme <стор-путь>` показывает свежую тему.

**Причина (не декларативный баг, а импеданс-мисматч Qt↔nix):** реальный greeter грузит тему
по стабильному пути `file:///run/current-system/sw/share/sddm/themes/ddlc/Main.qml` (меняется
только цель симлинка). Qt6 кэширует скомпилированный QML в `/var/lib/sddm/.cache/qmlcache/`,
ключ = абсолютный путь + mtime + размер. Все файлы в `/nix/store` имеют `mtime=1970` → путь
и mtime стабильны → Qt считает тему неизменной и отдаёт протухший `.qmlc`. `--test-mode`
спасает уникальным стор-путём (`/nix/store/<hash>-sddm-ddlc-theme/…`) — промах кэша, пересборка.

**Фикс (в `nixos/services/desktop/sddm.nix`):** отключён дисковый QML-кэш greeter'а —
`settings.General.GreeterEnvironment = "QT_WAYLAND_SHELL_INTEGRATION=layer-shell,QML_DISABLE_DISK_CACHE=1"`.
Модуль nixpkgs sddm.nix мёржит `recursiveUpdate defaultConfig cfg.settings` (settings
побеждает), поэтому wayland-интеграцию надо продублировать в этой же строке, иначе она
затрётся. Один раз снести накопленный кэш: `sudo rm -rf /var/lib/sddm/.cache`.

**Как деплоить правки экрана входа вообще:** `sudo nixos-rebuild switch` НЕ рестартит
`display-manager.service` (чтобы не убить сессию) → нужен `sudo systemctl restart display-manager`
(сессию не трогает) или ребут. `inputs.self`/`inherit inputs` тут ни при чём — сборка была
корректна всё время. См. [[sddm-pam-faildelay]].
