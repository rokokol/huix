{ config, lib, ... }:

# The handlers of the apps packages.nix installs. A key that ends in `*` takes every
# type shared-mime-info knows under that prefix, and an exact key overrides it, so a type that
# shared-mime-info renames is never left out. checks.nix refuses a key that is only an alias
let
  celluloid = "io.github.celluloid_player.Celluloid.desktop";
  evince = "org.gnome.Evince.desktop";
  fragments = "de.haeckerfelix.Fragments.desktop";
in
lib.mkIf config.rokokol.workstation.enable {
  xdg.mimeApps = {
    enable = true;

    defaultApplications = lib.mkMerge [
      {
        "audio/*" = celluloid;
        "video/*" = celluloid;
        "image/*" = "swayimg.desktop";

        "application/epub+zip" = evince;
        "application/pdf" = evince;
        "application/postscript" = evince;
        "application/vnd.comicbook+zip" = evince;
        "application/vnd.comicbook-rar" = evince;
        "application/x-bzpdf" = evince;
        "application/x-bzpostscript" = evince;
        "application/x-cb7" = evince;
        "application/x-cbt" = evince;
        "application/x-ext-djvu" = evince;
        "application/x-ext-pdf" = evince;
        "application/x-gzpdf" = evince;
        "application/x-gzpostscript" = evince;
        "application/x-xzpdf" = evince;
        "image/vnd.djvu" = evince;
        "image/vnd.djvu+multipage" = evince;

        "application/msword" = "writer.desktop";
        "application/rtf" = "writer.desktop";
        "application/vnd.ms-word*" = "writer.desktop";
        "application/vnd.oasis.opendocument.text*" = "writer.desktop";
        "application/vnd.openxmlformats-officedocument.wordprocessingml*" = "writer.desktop";
        "application/vnd.ms-excel*" = "calc.desktop";
        "application/vnd.oasis.opendocument.spreadsheet*" = "calc.desktop";
        "application/vnd.openxmlformats-officedocument.spreadsheetml*" = "calc.desktop";
        "application/vnd.ms-powerpoint*" = "impress.desktop";
        "application/vnd.oasis.opendocument.presentation*" = "impress.desktop";
        "application/vnd.openxmlformats-officedocument.presentationml*" = "impress.desktop";
        "application/vnd.oasis.opendocument.graphics*" = "draw.desktop";

        "application/x-bittorrent" = fragments;
        "x-scheme-handler/magnet" = fragments;

        "x-scheme-handler/mailto" = "org.gnome.Geary.desktop";
      }

      # The layered formats swayimg cannot read, where their editors are installed
      (lib.mkIf config.rokokol.packages.pc {
        "image/openraster" = "org.kde.krita.desktop";
        "image/vnd.adobe.photoshop" = "gimp.desktop";
        "image/x-xcf" = "gimp.desktop";
      })
    ];
  };
}
