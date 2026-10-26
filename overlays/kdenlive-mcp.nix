{ inputs, ... }:
# The MCP uses the same Qt-enabled MLT as Kdenlive for titles, previews and exports
_final: prev: {
  kdenlive-mcp = prev.rustPlatform.buildRustPackage {
    pname = "kdenlive-mcp-plus";
    version =
      (builtins.fromTOML (builtins.readFile "${inputs.kdenlive-mcp}/Cargo.toml")).package.version;

    src = inputs.kdenlive-mcp;

    cargoLock.lockFile = "${inputs.kdenlive-mcp}/Cargo.lock";

    postPatch = ''
      substituteInPlace tests/mcp_stdio.rs \
        --replace-fail '#!/bin/bash' '#!${prev.runtimeShell}'
    '';

    nativeBuildInputs = with prev; [
      pkg-config
      rustPlatform.bindgenHook
      kdePackages.wrapQtAppsHook
    ];
    buildInputs = with prev.kdePackages; [
      mlt
      qtbase
      qtsvg
    ];
    nativeCheckInputs = with prev; [
      ffmpeg-headless
      kdePackages.mlt
    ];
    checkFlags = [ "--test-threads=1" ];

    preCheck = ''
      export HOME="$TMPDIR"
      export QT_QPA_PLATFORM=offscreen
      export DISPLAY=:99
      export MLT_REPOSITORY=${prev.kdePackages.mlt}/lib/mlt-7
      export QT_PLUGIN_PATH=${prev.kdePackages.qtbase}/lib/qt-6/plugins
    '';

    preFixup = ''
      qtWrapperArgs+=(
        --prefix PATH : ${
          prev.lib.makeBinPath [
            prev.ffmpeg-headless
            prev.kdePackages.mlt
          ]
        }
        --set MLT_REPOSITORY ${prev.kdePackages.mlt}/lib/mlt-7
      )
    '';

    meta = {
      description = "MCP server for native Kdenlive projects and headless MLT exports";
      homepage = "https://github.com/crom-org/kdenlive-mcp-plus";
      license = prev.lib.licenses.mit;
      mainProgram = "kdenlive-mcp-plus";
      platforms = prev.lib.platforms.linux;
    };
  };
}
