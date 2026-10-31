# The Hindsight memory provider is a catalog plugin, not part of the Hermes tree.
# Its source is the Vectorize integration shipped beside the Hindsight server, and the
# provider imports the generated Python client from the same checkout.
{
  lib,
  python,
  source,
}:
let
  pluginVersion = lib.removePrefix "version: " (
    lib.findFirst (line: lib.hasPrefix "version: " line) "" (
      lib.splitString "\n" (builtins.readFile "${source}/hindsight-integrations/hermes/plugin.yaml")
    )
  );
  clientVersion =
    (builtins.fromTOML (builtins.readFile "${source}/hindsight-clients/python/pyproject.toml"))
    .project.version;
in
{
  # Hermes' sealed venv already carries the client's shared dependencies, and the wrapper
  # refuses a plugin package that would shadow one of them. Only aiohttp-retry is missing
  # there, and it is built without its own aiohttp so the sealed copy stays the only one
  aiohttpRetry = python.pkgs.aiohttp-retry.overridePythonAttrs (_: {
    dependencies = [ ];
    propagatedBuildInputs = [ ];
    dontCheckRuntimeDeps = true;
    doCheck = false;
    pythonImportsCheck = [ ];
  });

  client = python.pkgs.buildPythonPackage {
    pname = "hindsight-client";
    version = clientVersion;
    src = "${source}/hindsight-clients/python";
    format = "pyproject";
    build-system = [ python.pkgs.hatchling ];
    dependencies = [ ];
    # Shared dependencies come from Hermes' sealed venv; the wheel metadata still names them
    dontCheckRuntimeDeps = true;
    # The generated OpenAPI client ships no useful tests for this build
    doCheck = false;
    pythonImportsCheck = [ ];
    meta = {
      description = "Generated Python client for the Hindsight memory server";
      homepage = "https://github.com/vectorize-io/hindsight";
      license = lib.licenses.mit;
      platforms = lib.platforms.all;
    };
  };

  # The provider is published as an entry-point plugin. Hermes' memory-provider lookup resolves
  # a provider by its plugin directory name, so a directory symlink named after the Nix package
  # is invisible to it; the `hermes_agent.memory_providers` entry point is the supported path.
  provider = python.pkgs.buildPythonPackage {
    pname = "hermes-plugin-hindsight";
    version = pluginVersion;
    src = "${source}/hindsight-integrations/hermes";
    format = "pyproject";
    build-system = [ python.pkgs.hatchling ];
    dependencies = [ ];
    dontCheckRuntimeDeps = true;
    doCheck = false;
    pythonImportsCheck = [ ];
    postPatch = ''
      mkdir hindsight_hermes
      cp __init__.py config_schema.py embedded.py plugin.yaml settings.py setup.py templates.py hindsight_hermes/
      cat > pyproject.toml <<'EOF'
      [build-system]
      requires = ["hatchling"]
      build-backend = "hatchling.build"

      [project]
      name = "hermes-plugin-hindsight"
      version = "${pluginVersion}"
      description = "Hermes Agent memory provider plugin: hindsight"
      requires-python = ">=3.11"

      [project.entry-points."hermes_agent.memory_providers"]
      hindsight = "hindsight_hermes:register"

      [tool.hatch.build.targets.wheel]
      packages = ["hindsight_hermes"]
      EOF
    '';
    meta = {
      description = "Memory provider plugin for Hermes Agent backed by Hindsight";
      homepage = "https://github.com/vectorize-io/hindsight/tree/main/hindsight-integrations/hermes";
      license = lib.licenses.mit;
      platforms = lib.platforms.all;
    };
  };
}
