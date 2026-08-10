{ pkgs, ... }:

{
  home.packages = [ pkgs.claude-code ];

  programs.claude-account.enable = true;
}
