{ pkgs, ... }:

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
in
{
  home.packages = languageServers ++ formatters;

  programs.nixvim.extraPackages = languageServers ++ formatters;
}
