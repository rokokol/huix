{
  config,
  lib,
  osConfig,
  rokokolName,
  ...
}:

# The seam to rokokol/papers-skill: the module owns the paper-search-mcp package, both
# binaries on PATH, the PAPER_SEARCH_MCP_ENV_FILE variable, the MCP server, the skill's
# directory, the PaperQA2 environment and its pqa settings preset. This seam hands the skill to
# the agents beside the server. What the module ships none of is the env file with the keys, which
# nixos/services/tools/paper-search.nix renders from sops, and the corpus folder, which is
# the cache the skill downloads into. The Ollama models the preset names are pulled by hand
{
  # The env file exists only where the system's rokokol.paper-search is on
  options.rokokol.papers.enable = lib.mkEnableOption "the papers skill's tools" // {
    default = osConfig.rokokol.paper-search.enable;
    defaultText = lib.literalExpression "osConfig.rokokol.paper-search.enable";
  };

  config = lib.mkIf config.rokokol.papers.enable {
    programs.papers = {
      enable = true;
      envFile = osConfig.sops.templates."paper-search.env".path;
      corpus = {
        enable = true;
        directory = "/home/${rokokolName}/.cache/papers";
      };
    };

    rokokol.agents.skills.papers = config.programs.papers.skill;
    rokokol.agents.skillGroups.papers = "research";
    rokokol.agents.mcpGroups.paper-search = "research";
  };
}
