{ pkgs, ... }:

# nix-ld provides ld.so for non-Nix dynamically linked binaries: anything
# downloaded outside Nix (vendor SDKs, prebuilt CLIs, IDE servers, MATLAB,
# workshop tarballs) finds its shared libs via NIX_LD instead of dying with
# "No such file or directory". The list below is an FHS-like base that makes the
# NixOS machine behave "like Debian/Mint" for foreign binaries.
#
# If a specific binary still complains about a missing `lib*.so`, find the
# package that provides it and add it here — that's the whole support loop.
# For heavy/edge cases prefer wrapping the binary: `steam-run ./foo`
# (see ./appimage.nix), which gives it a full FHS sandbox

{
  programs.nix-ld.enable = true;

  programs.nix-ld.libraries = with pkgs; [
    # Core C/C++ runtime + system glue
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

    # Graphics / GL / Vulkan. The NVIDIA userspace is mixed in per-host from
    # nixos/pc/nvidia.nix so its version matches hardware.nvidia.package
    libGL
    libglvnd
    libdrm
    mesa
    vulkan-loader
    libgbm

    # GUI toolkits (GTK/Qt applications, Electron, browsers)
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

    # X11 / Wayland client libs (the xorg.* set is deprecated → top-level lib* names)
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

    # Sound
    alsa-lib
    libpulseaudio
    pipewire

    # Media / other frequently linked
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
