_: _final: prev: {
  pi-extensions = prev.buildNpmPackage {
    pname = "huix-pi-extensions";
    version = "0.0.0";
    src = builtins.path {
      name = "pi-extensions";
      path = ../home-manager/programs/agents/pi/extensions;
    };
    npmDeps = prev.importNpmLock {
      npmRoot = ../home-manager/programs/agents/pi/extensions;
    };
    npmConfigHook = prev.importNpmLock.npmConfigHook;
    npmFlags = [
      "--ignore-scripts"
      "--legacy-peer-deps"
    ];
    dontNpmBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/lib/pi-extensions"
      cp package.json package-lock.json "$out/lib/pi-extensions/"
      cp -r node_modules "$out/lib/pi-extensions/"
      runHook postInstall
    '';
    meta = {
      description = "Pinned Pi extensions for orchestration, permissions and session controls";
      homepage = "https://github.com/rokokol/huix";
      license = prev.lib.licenses.mit;
      platforms = prev.lib.platforms.linux;
    };
  };
}
