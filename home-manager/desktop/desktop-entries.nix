{ pkgs, ... }:

{
  # ... твои импорты и другие настройки

  # Создаем "ярлык" для Neovim, чтобы он был виден в списке приложений
  xdg.desktopEntries = {
    nvim = {
      name = "Neovim (Kitty)";
      genericName = "Text Editor";
      comment = "Edit text files in Neovim inside Kitty";
      exec = "kitty -e nvim %F"; # %F передает путь к файлу в nvim
      icon = "nvim";
      terminal = false; # Ставим false, так как мы сами запускаем kitty
      categories = [ "Utility" "TextEditor" "Development" ];
      mimeType = [ "text/plain" "text/markdown" "application/x-shellscript" ];
    };
  };
}


