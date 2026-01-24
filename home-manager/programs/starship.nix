{ ... }:

{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;

    settings = {
      "$schema" = "https://starship.rs/config-schema.json";

      # Path on top, input below
      format = "$os$username$directory$line_break$character";
      right_format = "$all";

      character = {
        success_symbol = "[❯](bold yellow) ";
        error_symbol = "[❯](bold red) ";
        vimcmd_symbol = "[❮](green) ";
      };

      username = {
        style_user = "bold blue";
        style_root = "bold red";
        format = "[$user]($style) || ";
        disabled = false;
        show_always = true;
      };

      cmd_duration = {
        min_time = 0;
        format = "took [$duration]($style) ";
        style = "bold yellow";
        show_milliseconds = true;
      };

      os = {
        disabled = false;
        style = "bold blue";
      };

      # Icons configuration
      directory.read_only = " 󰌾";
      aws.symbol = " ";
      buf.symbol = " ";
      c.symbol = " ";
      cpp.symbol = " ";
      cmake.symbol = " ";
      docker_context.symbol = " ";
      git_branch.symbol = " ";
      golang.symbol = " ";
      java.symbol = " ";
      kotlin.symbol = " ";
      lua.symbol = " ";
      memory_usage.symbol = "󰍛 ";
      nix_shell.symbol = " ";
      nodejs.symbol = " ";
      python.symbol = " ";
      rust.symbol = "󱘗 ";

      os.symbols = {
        Arch = " ";
        Debian = " ";
        Fedora = " ";
        Linux = " ";
        Macos = " ";
        NixOS = " ";
        Ubuntu = " ";
        Windows = "󰍲 ";
      };

      package.symbol = "󰏗 ";
    };
  };
}

