{
  config,
  rokokolName,
  ...
}:

# The API keys for paper-search-mcp, the paper search server behind the papers skill. The
# server reads them from an env file, so sops renders one from three secrets and the user
# layer's seam (home-manager/programs/cli/papers.nix) points the binaries at it. None of
# the three is required for the server to run; each unlocks a source's proper rate limit
# or, for Unpaywall, the open-access step of the download fallback
{
  sops.secrets."semantic-scholar-api-key" = { };
  sops.secrets."core-api-key" = { };
  sops.secrets."unpaywall-email" = { };

  sops.templates."paper-search.env" = {
    owner = rokokolName;
    content = ''
      PAPER_SEARCH_MCP_SEMANTIC_SCHOLAR_API_KEY=${config.sops.placeholder."semantic-scholar-api-key"}
      PAPER_SEARCH_MCP_CORE_API_KEY=${config.sops.placeholder."core-api-key"}
      PAPER_SEARCH_MCP_UNPAYWALL_EMAIL=${config.sops.placeholder."unpaywall-email"}
    '';
  };
}
