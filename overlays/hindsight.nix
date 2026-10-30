_: _final: prev:
let
  pythonPackages = prev.python3Packages.overrideScope (_pythonFinal: pythonPrev: {
    # FastMCP requires the MCP SDK's older API; other Python consumers keep their own SDK
    mcp = pythonPrev.mcp_1;
  });
in
{
  hindsight-api-slim = prev.hindsight-api-slim.override {
    python3Packages = pythonPackages;
  };
}
