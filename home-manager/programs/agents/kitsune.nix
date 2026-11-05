{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  version =
    (builtins.fromTOML (builtins.readFile "${inputs.kitsune}/pyproject.toml")).project.version;
  python = pkgs.python3Packages;
  kitsuneBrowser = python.buildPythonPackage {
    pname = "kitsune-browser";
    inherit version;
    src = inputs.kitsune;
    pyproject = true;
    build-system = [ python.hatchling ];
    dependencies = with python; [
      httpx
      pydantic
      websockets
    ];
    preFixup = ''
      export KITSUNE_HOME="$TMPDIR/kitsune"
    '';
    pythonImportsCheck = [ "kitsune.bridge" ];
    meta = {
      description = "Browser automation bridge for Firefox and Zen";
      homepage = "https://github.com/junyeong-nero/kitsune";
      license = lib.licenses.mit;
    };
  };
  kitsune = python.buildPythonApplication {
    pname = "kitsune-browser-mcp";
    inherit version;
    src = "${inputs.kitsune}/packages/kitsune-browser-mcp";
    pyproject = true;
    build-system = [ python.hatchling ];
    dependencies = [
      kitsuneBrowser
      python.mcp_1
    ];
    makeWrapperArgs = [
      "--prefix"
      "PYTHONPATH"
      ":"
      (python.makePythonPath (python.requiredPythonModules [ kitsuneBrowser ]))
    ];
    meta = {
      description = "MCP server for the Kitsune browser bridge";
      homepage = "https://github.com/junyeong-nero/kitsune";
      license = lib.licenses.mit;
      mainProgram = "kitsune";
    };
  };
  extension = pkgs.fetchurl {
    url = "https://github.com/junyeong-nero/kitsune/releases/download/v${version}/kitsune-${version}.xpi";
    hash = "sha256-o8vInrebusDHxDJpAQUFpBk1r+MfXQp6EyMqT2Dri38=";
  };
in
{
  options.rokokol.kitsune.enable = lib.mkEnableOption "the Kitsune browser MCP server" // {
    default = config.rokokol.workstation.enable && config.rokokol.zen.enable;
  };

  config = lib.mkIf config.rokokol.kitsune.enable {
    programs.mcp.servers.kitsune = {
      command = lib.getExe kitsune;
      env = {
        KITSUNE_ASK_BEFORE_ACT = "1";
        KITSUNE_USER_TABS = "read-only";
      };
    };
    programs.zen-browser.policies.ExtensionSettings."kitsune@junyeong-nero.github.io" = {
      installation_mode = "normal_installed";
      install_url = "file://${extension}";
      updates_disabled = true;
    };
  };
}
