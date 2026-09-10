{ osConfig, ... }:

# The seam to rokokol/papers-skill: the module owns the paper-search-mcp package, both
# binaries on PATH and the PAPER_SEARCH_MCP_ENV_FILE variable; the skill itself lives in
# ~/.local/share/claude-shared/skills like every other. What it ships none of is the env
# file with the keys, which nixos/services/tools/paper-search.nix renders from sops
{
  programs.papers = {
    enable = true;
    envFile = osConfig.sops.templates."paper-search.env".path;
  };
}
