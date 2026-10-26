{ inputs, ... }:
# dav-mcp is not in nixpkgs. It is plain JavaScript with no build step, so the package is its
# sources and their locked node_modules
_final: prev: {
  dav-mcp = prev.buildNpmPackage (finalAttrs: {
    pname = "dav-mcp";
    version = "5.0.0";

    src = inputs.dav-mcp;

    npmDeps = prev.importNpmLock { npmRoot = inputs.dav-mcp; };
    npmConfigHook = prev.importNpmLock.npmConfigHook;
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
