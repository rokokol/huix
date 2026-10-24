{
  pkgs,
  osConfig,
  huixDir,
  ...
}:

let
  languageServers = with pkgs; [
    bash-language-server
    clang-tools
    cmake-language-server
    dockerfile-language-server
    lua-language-server
    marksman
    nixd
    pyright
    rust-analyzer
    taplo
    texlab
    typescript-language-server
    vscode-langservers-extracted
    yaml-language-server
  ];
  formatters = with pkgs; [
    black
    nixfmt
    ruff
    rustc
    shfmt
    stylua
  ];

  # nixd completes the options of this host as the live checkout declares them
  host = "(builtins.getFlake \"${huixDir}\").nixosConfigurations.${osConfig.networking.hostName}";
  nixdConfig = {
    nixpkgs.expr = "${host}.pkgs";
    options = {
      nixos.expr = "${host}.options";
      home-manager.expr = "${host}.options.home-manager.users.type.getSubOptions [ ]";
    };
  };
in
{
  home.packages = languageServers ++ formatters;

  programs.nixvim.extraPackages = languageServers ++ formatters;

  # The agents start the servers of the languages the user writes, by the names installed above
  rokokol.agents.lspServers = {
    nixd = {
      command = "nixd";
      args = [ "--config=${builtins.toJSON nixdConfig}" ];
      extensions.".nix" = "nix";
    };
    lua-ls = {
      command = "lua-language-server";
      extensions.".lua" = "lua";
    };
    pyright = {
      command = "pyright-langserver";
      args = [ "--stdio" ];
      extensions = {
        ".py" = "python";
        ".pyi" = "python";
      };
    };
    rust = {
      command = "rust-analyzer";
      extensions.".rs" = "rust";
    };
    bash = {
      command = "bash-language-server";
      args = [ "start" ];
      extensions = {
        ".sh" = "shellscript";
        ".bash" = "shellscript";
      };
    };
    clangd = {
      command = "clangd";
      extensions = {
        ".c" = "c";
        ".h" = "c";
        ".cc" = "cpp";
        ".cpp" = "cpp";
        ".cxx" = "cpp";
        ".hh" = "cpp";
        ".hpp" = "cpp";
        ".hxx" = "cpp";
      };
    };
    marksman = {
      command = "marksman";
      args = [ "server" ];
      extensions.".md" = "markdown";
    };
  };
}
