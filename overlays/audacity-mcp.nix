{ inputs, ... }:
# Audacity exposes its script pipes through this MCP server, which nixpkgs does not package
_final: prev: {
  audacity-mcp = prev.python3Packages.buildPythonApplication {
    pname = "audacity-mcp-server";
    version = "0.1.24";
    pyproject = true;

    src = inputs.audacity-mcp;

    build-system = with prev.python3Packages; [ hatchling ];
    dependencies =
      with prev.python3Packages;
      [
        mcp_1
        faster-whisper
      ]
      ++ mcp_1.optional-dependencies.cli;
    pythonImportsCheck = [ "audacity_mcp.main" ];

    meta = {
      description = "MCP server for audio effects through Audacity script pipes";
      homepage = "https://github.com/xDarkzx/Audacity-MCP";
      license = prev.lib.licenses.asl20;
      mainProgram = "audacity-mcp";
      platforms = prev.lib.platforms.linux;
    };
  };
}
