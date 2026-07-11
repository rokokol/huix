{ pkgs, ... }:

# Запуск чужих бинарников «чтобы просто работало», два дополняющих инструмента:
#
#   * programs.appimage.binfmt — регистрирует обработчик binfmt_misc, чтобы
#     запускать любой *.AppImage напрямую (./Foo.AppImage), без chmod-and-pray и
#     распаковки. Типичный формат раздачи на воркшопах/мастер-классах.
#
#   * steam-run — оборачивает произвольную команду в полноценный FHS-песочник
#     (настоящие /usr, /lib, ld.so). Когда базы nix-ld из ./nix-ld.nix не хватает
#     упрямому пребилту: `steam-run ./installer` — и он ведёт себя как в обычном
#     дистрибутиве. Более тяжёлый молоток; берём во вторую очередь.

{
  programs.appimage = {
    enable = true;
    binfmt = true; # double-click / ./Foo.AppImage runs directly
  };

  environment.systemPackages = with pkgs; [
    steam-run # `steam-run <cmd>`: FHS sandbox for any prebuilt binary
  ];
}
