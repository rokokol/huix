{ pkgs, ... }:

# The profile switcher lives in github:rokokol/claude-account. Enabling it installs the
# switcher, pins CLAUDE_CONFIG_DIR and repairs the active profile's links on every
# activation — huix only says when, and brings the binary the switcher switches between
{
  home.packages = [ pkgs.claude-code ];

  programs.claude-account.enable = true;
}
