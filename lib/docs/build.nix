{ pkgs, inputs }:
# The documentation corpus and what is built from it: the site a reader opens and the server an
# agent asks. The facts come from the flake evaluation rather than from a command run at build
# time, so the sandbox renders a corpus that cannot disagree with the configuration it describes
let
  inherit (pkgs)
    coreutils
    lib
    nix
    python3
    ripgrep
    runCommand
    writeShellApplication
    writeShellScriptBin
    writers
    ;
  pythonDocs = python3.withPackages (python: [ python.markdown ]);

  # What each output is and what it may be used for: the checker asks both of every package
  described =
    text: package:
    lib.addMetaAttrs {
      description = text;
      license = lib.licenses.mit;
    } package;

  src = builtins.path {
    name = "huix-docs-source";
    path = inputs.self;
  };

  siteFonts = builtins.path {
    name = "ddlc-site-fonts";
    path = "${inputs.ddlc-themes}/dist";
    filter =
      path: type:
      type == "directory"
      || builtins.elem (builtins.baseNameOf path) [
        "DepartureMono-Regular.woff2"
        "DepartureMono-LICENSE.txt"
        "MyaNunito.woff2"
        "MyaNunito-Italic.woff2"
        "MyaNunito-LICENSE.txt"
      ];
  };

  facts = import ./facts.nix {
    inherit lib;
    inherit (inputs) self;
  };

  factsJson = writers.writeJSON "huix-docs-facts.json" facts;

  # What the renderer reads: the modules for their comments and their units, the scripts for the
  # help they print, the pages themselves and the assets of the site. The pictures of the
  # repository are large and no page is built from them
  renderSource = runCommand "huix-docs-render-source" { } ''
    mkdir -p $out/assets
    cp -r ${src}/docs ${src}/nixos ${src}/home-manager ${src}/lib ${src}/scripts ${src}/site $out/
    cp ${src}/assets/can-you-read-this-with-me.jpg $out/assets/
    cp ${src}/flake.nix ${src}/checks.nix $out/
    cp ${src}/*.md $out/
  '';

  corpus = described "Documentation of this configuration, rendered from its own facts" (
    runCommand "huix-docs" { nativeBuildInputs = [ python3 ]; } ''
      cp -r ${renderSource} $out
      chmod -R u+w $out
      python3 -B $out/scripts/docs-build.py inject --strict --facts ${factsJson} --repo $out
    ''
  );

  site = described "Documentation corpus as a static site on the DDLC web kit" (
    runCommand "huix-docs-site" { nativeBuildInputs = [ pythonDocs ]; } ''
      cp -r ${corpus} web
      chmod -R u+w web
      python3 -B web/scripts/docs-build.py site --facts ${factsJson} --repo web --out $out
      cp ${siteFonts}/*.woff2 ${siteFonts}/*-LICENSE.txt $out/assets/vendor/ddlc/
    ''
  );

  # `nix run .#docs-mcp` — the corpus of this revision answered over stdio, without a checkout
  mcp = described "MCP server over the documentation of this configuration, offline and read-only" (
    writeShellScriptBin "huix-docs-mcp" ''
      exec ${python3}/bin/python3 -B ${corpus}/scripts/docs-mcp.py --repo ${corpus} "$@"
    ''
  );

  # A configuration that gained a module and no page is as broken as a page that lags the
  # configuration, and a person reads neither
  check =
    runCommand "check-docs"
      {
        nativeBuildInputs = [
          python3
          ripgrep
        ];
      }
      ''
        set -euo pipefail
        cp -r ${renderSource} work
        chmod -R u+w work
        python3 -B work/scripts/docs-build.py check --strict --facts ${factsJson} --repo work || {
          echo "the pages of docs/ lag this tree: run \`nix run .#docs-build\` and commit them" >&2
          exit 1
        }
        python3 -B work/scripts/tests/test-docs-build.py
        python3 -B work/scripts/tests/test-docs-mcp.py
        python3 -B work/scripts/tests/test-eval-docs-search.py
        # A question set shows the search getting worse, and the number is worth reading even in a
        # log nobody opens until it is red
        python3 -B work/scripts/tests/eval-docs-search.py --min-recall 0.7
        touch $out
      '';

  # `nix run .#docs-build` — render the pages of this checkout and write them back into it. The
  # render happens in the sandbox, so the pages a person commits are the pages the check builds:
  # a script's --help comes from the interpreter of the build rather than from whichever python
  # the shell happens to hold
  writeback = writeShellApplication {
    name = "docs-build";
    runtimeInputs = [
      coreutils
      nix
    ];
    text = ''
      repo="''${1:-$PWD}"
      rendered=$(nix build --print-out-paths "path:$repo#huix-docs" --impure)
      cp -r "$rendered"/docs/. "$repo"/docs/
      echo "wrote the pages of $repo/docs"
    '';
  };

  # `nix run .#docs-site` — serve the built site on this machine alone
  serve = writeShellApplication {
    name = "docs-site";
    runtimeInputs = [ python3 ];
    text = ''
      site=$(nix build --print-out-paths "path:''${1:-$PWD}#huix-docs-site" --impure)
      echo "http://127.0.0.1:8099/"
      exec python3 -m http.server 8099 --bind 127.0.0.1 --directory "$site"
    '';
  };
in
{
  inherit
    corpus
    factsJson
    mcp
    site
    check
    serve
    writeback
    ;
}
