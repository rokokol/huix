# Memory index

- [SDDM QML-кэш протухает](sddm-qml-cache-stale.md) — правки DDLC-темы не видны на реальном логине из-за дискового QML-кэша Qt + mtime=1970; фикс QML_DISABLE_DISK_CACHE.
- [Пакеты Мии](mya-agent-packages.md) — команды `mya` идут через `users.users.mya.packages` (`agent.nix` + `configuration-station.nix`), не через `home.packages`; `curl` и `jq` уже в базовом списке.
