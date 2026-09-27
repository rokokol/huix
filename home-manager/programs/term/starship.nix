_:

{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;

    settings = {
      "$schema" = "https://starship.rs/config-schema.json";

      # Path on top, input below
      format = "$os$username$directory$line_break$character";
      right_format = "$all$cmd_duration$time";

      # Colours are ANSI slots, never hexes: kitty fills them from its DDLC light or dark theme,
      # so the prompt follows the theme toggle. purple is pink or plum, cyan is rule, and 20 is
      # natsuki on dark and yuri on light
      character = {
        success_symbol = "[❯](bold purple) ";
        error_symbol = "[❯](bold red) ";
        vimcmd_symbol = "[❮](green) ";
      };

      username = {
        style_user = "bold 20";
        style_root = "bold red";
        format = "[$user]($style) || ";
        disabled = false;
        show_always = true;
      };

      cmd_duration = {
        min_time = 0;
        format = "took [$duration](bold cyan) [󱎫](cyan) ";
        show_milliseconds = true;
      };

      time = {
        disabled = false;
        format = "at [$time](bold cyan) [󰃰](cyan) ";
        time_format = "%H:%M";
      };

      os = {
        disabled = false;
        style = "bold purple";
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
