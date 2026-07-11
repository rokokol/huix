{ pkgs, ... }:

# nix-ld даёт ld.so для не-Nix динамически слинкованных бинарников: всё, что
# скачано вне Nix (вендорские SDK, пребилт-CLI, IDE-серверы, MATLAB, тарболлы с
# воркшопов), находит свои shared-либы через NIX_LD, а не умирает с
# "No such file or directory". Список ниже — FHS-подобная база, из-за которой
# NixOS-машина ведёт себя «как Debian/Mint» для чужих бинарников.
#
# Если конкретный бинарник всё ещё жалуется на отсутствующий `lib*.so`, найди
# пакет, который его даёт, и добавь сюда — в этом весь цикл поддержки.
# Для тяжёлых/краевых случаев лучше оборачивать бинарник: `steam-run ./foo`
# (см. ./appimage.nix), это даёт ему полный FHS-песочник.

{
  programs.nix-ld.enable = true;

  programs.nix-ld.libraries = with pkgs; [
    # Ядро C/C++ рантайма + системный клей
    stdenv.cc.cc
    stdenv.cc.cc.lib
    zlib
    zstd
    xz
    bzip2
    openssl
    curl
    libssh
    libssh2
    pam
    acl
    attr
    util-linux # libuuid, libmount, libblkid
    systemd # libsystemd, libudev
    libcap
    libxcrypt
    icu
    libxml2
    libxslt
    expat
    pcre2

    # Графика / GL / Vulkan. Userspace NVIDIA домешивается per-host из
    # nixos/pc/nvidia.nix, чтобы его версия совпадала с hardware.nvidia.package.
    libGL
    libglvnd
    libdrm
    mesa
    vulkan-loader
    libgbm

    # GUI-тулкиты (GTK/Qt приложения, Electron, браузеры)
    glib
    gtk3
    gdk-pixbuf
    pango
    cairo
    atk
    at-spi2-atk
    at-spi2-core
    gobject-introspection
    harfbuzz
    fontconfig
    freetype
    fribidi
    dbus
    cups
    nspr
    nss
    libnotify
    libappindicator-gtk3
    librsvg

    # Клиентские либы X11 / Wayland (набор xorg.* устарел → имена lib* верхнего уровня)
    libx11
    libxext
    libxrender
    libxrandr
    libxcursor
    libxi
    libxfixes
    libxdamage
    libxcomposite
    libxtst
    libxscrnsaver
    libxcb
    libxft
    libxshmfence
    libxkbcommon
    wayland

    # Звук
    alsa-lib
    libpulseaudio
    pipewire

    # Медиа / прочее часто линкуемое
    ffmpeg
    libusb1
    libuv
    libsodium
    libunwind
    flac
    libvorbis
    libjpeg
    libpng
    gmp
  ];
}
