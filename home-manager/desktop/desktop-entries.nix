{ pkgs, ... }:

{
  xdg.desktopEntries = {
    nvim = {
      name = "Neovim (Kitty)";
      genericName = "Text Editor";
      comment = "Edit text files in Neovim inside Kitty";
      exec = "kitty -e nvim %F"; # %F gives file path to vim
      icon = "nvim";
      terminal = false;
      categories = [ "Utility" "TextEditor" "Development" ];
      mimeType = [ "text/plain" "text/markdown" "application/x-shellscript" ];
    };
  };
}


