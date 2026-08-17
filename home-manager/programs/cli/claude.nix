{ pkgs, ... }:

# Profile switching and shared OpenCode config live in rokokol/claude-account
{
  home.packages = [ pkgs.claude-code ];

  programs.claude-account = {
    enable = true;
    opencode.enable = true;
  };
}
