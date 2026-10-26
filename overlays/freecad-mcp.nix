{ inputs, ... }:
# freecad-mcp is not in nixpkgs. Its source holds both halves: the MCP server packaged here, and
# the FreeCAD addon, which home-manager/programs/creative/freecad.nix installs
# from the same source
_final: prev: {
  freecad-mcp = prev.python3Packages.buildPythonApplication {
    pname = "freecad-mcp";
    version = "0.1.27";
    pyproject = true;

    src = inputs.freecad-mcp;

    build-system = with prev.python3Packages; [ hatchling ];

    dependencies =
      with prev.python3Packages;
      [
        mcp_1
        validators
      ]
      ++ mcp_1.optional-dependencies.cli;

    # stdio_client filters the environment. The test child needs Nix's dependency paths
    postPatch = ''
      substituteInPlace tests/test_tool_errors.py \
        --replace-fail 'import asyncio' $'import asyncio\nimport os' \
        --replace-fail 'StdioServerParameters(command=sys.executable, args=[str(Path(__file__))])' \
          'StdioServerParameters(command=sys.executable, args=[str(Path(__file__))], env={"PYTHONPATH": os.environ.get("PYTHONPATH", "")})'
    '';

    nativeCheckInputs = with prev.python3Packages; [ pytestCheckHook ];

    pythonImportsCheck = [ "freecad_mcp" ];

    meta = {
      description = "MCP server that drives a running FreeCAD through its RPC addon";
      homepage = "https://github.com/neka-nat/freecad-mcp";
      license = prev.lib.licenses.mit;
      mainProgram = "freecad-mcp";
      platforms = prev.lib.platforms.all;
    };
  };
}
