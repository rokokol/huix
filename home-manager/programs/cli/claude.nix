{ pkgs, ... }:

# Profile switching lives in rokokol/claude-account, which pins CLAUDE_CONFIG_DIR and runs
# "claude-account ensure" on every activation — neither belongs here as well
{
  home.packages = [ pkgs.claude-code ];

  programs.claude-account.enable = true;
}
