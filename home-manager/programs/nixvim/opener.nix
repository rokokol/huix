{ config, lib, ... }:

# nvim's own desktop file asks for a terminal, and xdg-open cannot provide one, so this entry
# opens it in a kitty window. It only serves as an opener, so the launcher hides it
lib.mkIf (config.programs.nixvim.enable && config.rokokol.workstation.enable) {
  xdg.desktopEntries.nvim-kitty = {
    name = "Neovim";
    genericName = "Text Editor";
    exec = "kitty nvim %F";
    icon = "nvim";
    noDisplay = true;
  };

  xdg.mimeApps = {
    enable = true;
    # All of text/, and the text formats that shared-mime-info files under application/
    defaultApplications = lib.genAttrs [
      "application/json"
      "application/sql"
      "application/toml"
      "application/x-desktop"
      "application/x-zerosize"
      "application/xml"
      "application/yaml"
      "text/*"
    ] (_: "nvim-kitty.desktop");
  };
}
