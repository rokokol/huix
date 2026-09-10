{ osConfig, rokokolName, ... }:

# The seam to rokokol/papers-skill: the module owns the paper-search-mcp package, both
# binaries on PATH, the PAPER_SEARCH_MCP_ENV_FILE variable, the PaperQA2 environment and
# its pqa settings preset; the skill itself lives in ~/.local/share/claude-shared/skills
# like every other. What it ships none of is the env file with the keys, which
# nixos/services/tools/paper-search.nix renders from sops, and the corpus folder, which is
# the cache the skill downloads into. The Ollama models the preset names are pulled by hand
{
  programs.papers = {
    enable = true;
    envFile = osConfig.sops.templates."paper-search.env".path;
    corpus = {
      enable = true;
      directory = "/home/${rokokolName}/.cache/papers";
    };
  };
}
