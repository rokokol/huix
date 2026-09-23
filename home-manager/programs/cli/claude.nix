{ config, pkgs, ... }:

# Profile switching and shared OpenCode config live in rokokol/claude-account
let
  sharedDir = "${config.xdg.dataHome}/claude-shared";
in
{
  home.packages = with pkgs; [ claude-code ];

  programs.claude-account = {
    enable = true;
    opencode.enable = true;
    # The module leaves this null and its script picks the same path on its own, where Nix
    # cannot read it back. Naming it here is what lets SKILLS_DIR follow the directory
    inherit sharedDir;
  };

  # Each shared skill is a checkout of its own repository, so sync.sh sweeps this directory
  home.sessionVariables.SKILLS_DIR = "${sharedDir}/skills";
}
