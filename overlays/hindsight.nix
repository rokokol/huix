_: _final: prev:
let
  pythonPackages = prev.python3Packages.overrideScope (
    _pythonFinal: pythonPrev: {
      # See WORKAROUNDS.md: Hindsight uses a compatible MCP Python SDK
      mcp = pythonPrev.mcp_1;
    }
  );
in
{
  hindsight-api-slim = prev.hindsight-api-slim.override {
    python3Packages = pythonPackages;
  };
}
