{ inputs, ... }:
# The MCP server and Blender addon come from one source to keep their protocol in sync
_final: prev: {
  blender-mcp = prev.python3Packages.buildPythonApplication {
    pname = "mcp-for-blender";
    version = "2.2.4";
    pyproject = true;

    src = inputs.blender-mcp;

    build-system = with prev.python3Packages; [ setuptools ];
    dependencies = with prev.python3Packages; [
      mcp_1
      httpx
    ];
    pythonImportsCheck = [ "blender_mcp.server" ];

    meta = {
      description = "MCP server that connects agents to the Blender addon";
      homepage = "https://github.com/ahujasid/blender-mcp";
      license = prev.lib.licenses.mit;
      mainProgram = "mcp-for-blender";
      platforms = prev.lib.platforms.linux;
    };
  };
}
