{ config, lib, ... }:

# nvim's own desktop file asks for a terminal, and xdg-open cannot provide one, so this entry
# opens it in a kitty window. It only serves as an opener, so the launcher hides it
lib.mkIf config.programs.nixvim.enable {
  xdg.desktopEntries.nvim-kitty = {
    name = "Neovim";
    genericName = "Text Editor";
    exec = "kitty nvim %F";
    icon = "nvim";
    noDisplay = true;
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = lib.genAttrs [
      "application/json"
      "application/x-zerosize"
      "text/markdown"
      "text/plain"
      "text/x-markdown"
      "text/x-tex"
    ] (_: "nvim-kitty.desktop");
  };
}
