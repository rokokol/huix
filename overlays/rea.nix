{ inputs, ... }:
# REA ships its MCP server, CLI, Ghidra bridge and matching investigation skill together
_final: prev: {
  rea = prev.buildNpmPackage {
    pname = "rea-agents";
    inherit (builtins.fromJSON (builtins.readFile "${inputs.rea}/package.json")) version;
    src = inputs.rea;
    nodejs = prev.nodejs_26;
    npmDeps = prev.importNpmLock { npmRoot = inputs.rea; };
    npmConfigHook = prev.importNpmLock.npmConfigHook;
    npmFlags = [ "--ignore-scripts" ];
    nativeBuildInputs = with prev; [
      autoPatchelfHook
      makeWrapper
    ];
    buildInputs = [ prev.stdenv.cc.cc.lib ];
    preBuild = ''
      export HOME="$TMPDIR"
      export HUSKY=0
      # The development tree includes musl variants; the installed package check stays strict
      autoPatchelfIgnoreMissingDeps="libc.musl-x86_64.so.1" autoPatchelf node_modules
    '';
    postInstall = ''
      wrapProgram $out/bin/rea \
        --prefix PATH : ${
          prev.lib.makeBinPath [
            prev.procps
            prev.util-linux
          ]
        }
    '';
    meta = {
      description = "Reverse engineering CLI and MCP server for binaries and applications";
      homepage = "https://github.com/morluto/rea";
      license = prev.lib.licenses.mit;
      mainProgram = "rea";
      platforms = [ "x86_64-linux" ];
    };
  };
}
