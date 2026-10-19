_:
# dav-mcp is not in nixpkgs. It is plain JavaScript with no build step, so the package is its
# sources and their locked node_modules
_final: prev: {
  dav-mcp = prev.buildNpmPackage (finalAttrs: {
    pname = "dav-mcp";
    version = "5.0.0";

    src = prev.fetchFromGitHub {
      owner = "PhilflowIO";
      repo = "dav-mcp";
      tag = "v${finalAttrs.version}";
      hash = "sha256-JHtJpZH/UTo3H4EEpwR75RXqrnX8885lb+TBmyDsFaY=";
    };

    npmDepsHash = "sha256-vJ8B01MwQmL3kHTCtLrQ+YJGvAflnY1zkkLmethvn1k=";
    dontNpmBuild = true;

    meta = {
      description = "MCP server for CalDAV calendars, tasks and CardDAV contacts";
      homepage = "https://github.com/PhilflowIO/dav-mcp";
      changelog = "https://github.com/PhilflowIO/dav-mcp/blob/v${finalAttrs.version}/CHANGELOG.md";
      license = prev.lib.licenses.mit;
      mainProgram = "dav-mcp";
      platforms = prev.lib.platforms.all;
    };
  });
}
