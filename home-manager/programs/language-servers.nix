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
in
{
  home.packages = languageServers;

  programs.nixvim.extraPackages = languageServers;
}
