{
  config,
  lib,
  rokokolName,
  ...
}:

# The private settings of paper-search-mcp, the paper search server behind the papers skill.
# The server reads them from an env file, so sops renders one and the user layer's seam
# (home-manager/programs/agents/research/papers.nix) points the binaries at it. It holds the
# Unpaywall address alone, for the open-access step of the download fallback. The sources take
# no key: an invalid Semantic Scholar key is refused where no key is answered
{
  options.rokokol.paper-search.enable = lib.mkEnableOption "the paper-search-mcp settings file" // {
    default = config.rokokol.workstation.enable;
  };

  config = lib.mkIf config.rokokol.paper-search.enable {
    sops.secrets."unpaywall-email" = { };

    sops.templates."paper-search.env" = {
      owner = rokokolName;
      content = ''
        PAPER_SEARCH_MCP_UNPAYWALL_EMAIL=${config.sops.placeholder."unpaywall-email"}
      '';
    };
  };
}
