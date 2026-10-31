{
  config,
  lib,
  pkgs,
  osConfig,
  huixDir,
  ...
}:

let
  json = pkgs.formats.json { };
  # nixd completes the options of this host as the live checkout declares them
  host = "(builtins.getFlake \"${huixDir}\").nixosConfigurations.${osConfig.networking.hostName}";
  nixdConfig = {
    nixpkgs.expr = "${host}.pkgs";
    options = {
      nixos.expr = "${host}.options";
      home-manager.expr = "${host}.options.home-manager.users.type.getSubOptions [ ]";
    };
  };
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
  # If on-demand startup is too slow, pi-lsp-adapter keeps servers warm.
  servers = {
    nixd = {
      command = [
        "nixd"
        "--config=${builtins.toJSON nixdConfig}"
      ];
      extensions = [ ".nix" ];
    };
    lua-language-server = {
      command = [ "lua-language-server" ];
      extensions = [ ".lua" ];
      pushDiagnosticsGraceMs = 3000;
    };
    pyright = {
      command = [
        "pyright-langserver"
        "--stdio"
      ];
      extensions = [
        ".py"
        ".pyi"
      ];
    };
    rust-analyzer = {
      command = [ "rust-analyzer" ];
      extensions = [ ".rs" ];
      pullDiagnosticsGraceMs = 5000;
    };
    bash-language-server = {
      command = [
        "bash-language-server"
        "start"
      ];
      extensions = [
        ".sh"
        ".bash"
      ];
    };
    clangd = {
      command = [ "clangd" ];
      extensions = [
        ".c"
        ".h"
        ".cc"
        ".cpp"
        ".cxx"
        ".hh"
        ".hpp"
        ".hxx"
      ];
    };
    marksman = {
      command = [
        "marksman"
        "server"
      ];
      extensions = [ ".md" ];
    };
    texlab = {
      command = [ "texlab" ];
      extensions = [
        ".tex"
        ".bib"
      ];
    };
    yaml-language-server = {
      command = [
        "yaml-language-server"
        "--stdio"
      ];
      extensions = [
        ".yaml"
        ".yml"
      ];
    };
    taplo = {
      command = [
        "taplo"
        "lsp"
        "stdio"
      ];
      extensions = [ ".toml" ];
    };
  };
in
{
  home.packages = languageServers ++ formatters;

  programs.nixvim.extraPackages = languageServers ++ formatters;

  home.file = lib.mkIf config.programs.pi-coding-agent.enable {
    "${config.programs.pi-coding-agent.configDir}/pi-lsp.json".source = json.generate "pi-lsp.json" {
      # bash-language-server indexes the whole workspace; 20s was too short
      timeout = 120000;
      inherit servers;
    };
  };
}
