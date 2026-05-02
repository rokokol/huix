{ ... }:

{
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "zen.desktop";
      "x-scheme-handler/http" = "zen.desktop";
      "x-scheme-handler/https" = "zen.desktop";
      "x-scheme-handler/about" = "zen.desktop";
      "x-scheme-handler/unknown" = "zen.desktop";
      "inode/directory" = "thunar.desktop";
      "application/x-directory" = "thunar.desktop";

      "image/jpeg" = "swayimg.desktop";
      "image/png" = "swayimg.desktop";
      "image/gif" = "swayimg.desktop";
      "image/x-canon-cr2" = "swayimg.desktop";
      "image/x-raw" = "swayimg.desktop";
      "image/x-dcraw" = "swayimg.desktop";
      "image/tiff" = "swayimg.desktop";
      "image/bmp" = "swayimg.desktop";
      "image/webp" = "swayimg.desktop";

      "video/mp4" = "io.github.celluloid_player.Celluloid.desktop";
      "video/x-matroska" = "io.github.celluloid_player.Celluloid.desktop";
      "video/webm" = "io.github.celluloid_player.Celluloid.desktop";
      "video/quicktime" = "io.github.celluloid_player.Celluloid.desktop";
      "video/x-msvideo" = "io.github.celluloid_player.Celluloid.desktop";
      "video/mpeg" = "io.github.celluloid_player.Celluloid.desktop";
      "video/3gpp" = "io.github.celluloid_player.Celluloid.desktop";

      "application/pdf" = "org.gnome.Evince.desktop";
      "application/x-bzpdf" = "org.gnome.Evince.desktop";
      "application/x-gzpdf" = "org.gnome.Evince.desktop";
      "application/x-ext-pdf" = "org.gnome.Evince.desktop";
      "application/postscript" = "org.gnome.Evince.desktop";
      "application/x-bzpostscript" = "org.gnome.Evince.desktop";
      "application/x-gzpostscript" = "org.gnome.Evince.desktop";
      "image/vnd.djvu" = "org.gnome.Evince.desktop";
      "application/x-ext-djvu" = "org.gnome.Evince.desktop";
      "application/x-cbz" = "org.gnome.Evince.desktop";
      "application/x-cbr" = "org.gnome.Evince.desktop";
      "application/epub+zip" = "org.gnome.Evince.desktop";

      "application/zip" = "org.gnome.FileRoller.desktop";
      "application/x-7z-compressed" = "org.gnome.FileRoller.desktop";
      "application/x-bzip2" = "org.gnome.FileRoller.desktop";
      "application/x-gzip" = "org.gnome.FileRoller.desktop";
      "application/x-rar" = "org.gnome.FileRoller.desktop";
      "application/x-tar" = "org.gnome.FileRoller.desktop";
      "application/x-xz" = "org.gnome.FileRoller.desktop";
      "application/vnd.rar" = "org.gnome.FileRoller.desktop";

      "text/markdown" = "org.gnome.TextEditor.desktop";
      "text/plain" = "org.gnome.TextEditor.desktop";
      "text/x-markdown" = "org.gnome.TextEditor.desktop";
      "application/x-zerosize" = "org.gnome.TextEditor.desktop";

      "application/octet-stream" = "selectdefaultapplication.desktop";
    };
  };
}
