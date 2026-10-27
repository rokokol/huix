{
  pkgs,
  inputs,
  rokokolName,
  ...
}:
# nix flake check already evaluates every host. The nixvim entries add the one thing
# evaluation cannot say: whether the Lua nixvim assembles out of every module is
# parseable — nixvim runs stylua over the generated init.lua, so a syntax error fails
# the build. The station's VM test is not here; flake.nix says why
# nix-lint holds every .nix file here to the standard the skill carries. It runs in a
# build sandbox, so it leaves out the rules that need this flake's inputs; the eval
# job runs the whole checker through apps.check-nix, where the inputs are there
pkgs.lib.mapAttrs' (
  name: cfg:
  pkgs.lib.nameValuePair "nixvim-init-${name}"
    cfg.config.home-manager.users.${rokokolName}.programs.nixvim.build.initFile
) inputs.self.nixosConfigurations
// {
  nix-lint = inputs.skill-nix-best-practices.lib.mkCheck {
    inherit pkgs;
    root = ./.;
    namespaces = [ "rokokol" ];
  };

  # The scripts against stubbed commands: every keyword rotate-screen.sh and
  # tablet-mode.sh emit is asserted here, where there is no compositor to ask.
  # make-station-iso.sh runs the real xorriso on a small image
  script-tests =
    pkgs.runCommand "script-tests"
      {
        nativeBuildInputs = with pkgs; [
          # sync.sh runs against real repositories made by the tests
          git
          jq
          # The Hermes scripts read config.yaml as Hermes writes it
          (python3.withPackages (ps: [ ps.ruamel-yaml ]))
          # flock, which alert.sh takes its lock with
          util-linux
          xorriso
        ];
        scripts = builtins.path {
          name = "huix-scripts";
          path = ./scripts;
        };
      }
      ''
        bash "$scripts/tests/run.sh"
        python3 -B "$scripts/tests/test-hermes-monitor.py"
        python3 -B "$scripts/tests/test-hermes-seed-config.py"
        touch "$out"
      '';

  # xdg-open looks a default up under the canonical name file(1) gives, and never resolves an
  # alias, so a mimeapps.list key that is only an alias leaves its files without a handler
  mime-aliases =
    let
      keys = pkgs.lib.concatLists (
        pkgs.lib.mapAttrsToList (
          host: cfg:
          let
            mimeApps = cfg.config.home-manager.users.${rokokolName}.xdg.mimeApps;
          in
          pkgs.lib.optionals mimeApps.enable (
            map (key: "${host} ${key}") (
              pkgs.lib.concatMap builtins.attrNames [
                mimeApps.defaultApplications
                mimeApps.associations.added
                mimeApps.associations.removed
              ]
            )
          )
        ) inputs.self.nixosConfigurations
      );
    in
    pkgs.runCommand "mime-aliases"
      {
        keys = pkgs.writeText "mime-keys" (pkgs.lib.concatLines keys);
        aliases = "${pkgs.shared-mime-info}/share/mime/aliases";
      }
      ''
        found=$(awk 'NR == FNR { canonical[$1] = $2; next }
          $2 in canonical { print $1 ": " $2 " is an alias of " canonical[$2] }' "$aliases" "$keys")
        if [[ -n $found ]]; then
          printf '%s\n' "$found" >&2
          exit 1
        fi
        touch "$out"
      '';

  # sync.sh reads a few variables from outside, and the unit and the syssync alias each pass
  # them. Each host's unit and alias must pass exactly what the script reads, so a variable is
  # neither missing in one of them nor passed for nothing. The login gives HOME
  sync-env =
    let
      entries = pkgs.lib.concatLists (
        pkgs.lib.mapAttrsToList (
          host: cfg:
          let
            hm = cfg.config.home-manager.users.${rokokolName};
            unitNames = map (entry: pkgs.lib.head (pkgs.lib.splitString "=" entry)) (
              pkgs.lib.filter (
                entry: !pkgs.lib.hasPrefix "PATH=" entry
              ) hm.systemd.user.services.sync.Service.Environment
            );
          in
          pkgs.lib.optionals hm.rokokol.sync.enable [
            "${host} unit ${toString unitNames}"
            "${host} alias ${hm.home.shellAliases.syssync}"
          ]
        ) inputs.self.nixosConfigurations
      );
    in
    pkgs.runCommand "sync-env"
      {
        entries = pkgs.writeText "sync-env-entries" (pkgs.lib.concatLines entries);
        script = builtins.path {
          name = "sync-sh";
          path = ./scripts/sync.sh;
        };
      }
      ''
        assigned() {
          grep -Eq "(^|[^A-Za-z0-9_])(local|declare|export|mapfile)?( -[A-Za-z]+)* *$1(\[[^]]*\])?\+?=|(mapfile|declare|local)( -[A-Za-z]+)+ $1( |$)" "$script"
        }
        read_names=$(grep -oE '\$\{?[A-Z_][A-Z0-9_]*' "$script" | tr -d '$' | tr -d '{' | sort -u |
          while read -r name; do
            [ "$name" = HOME ] || assigned "$name" || printf '%s\n' "$name"
          done)
        if [ -z "$read_names" ]; then
          echo "sync-env: found no variable sync.sh reads, so the search is broken" >&2
          exit 1
        fi
        status=0
        while read -r host kind rest; do
          if [ "$kind" = alias ]; then
            passed=$(for word in $rest; do
              case $word in *=*) printf '%s\n' "''${word%%=*}" ;; *) break ;; esac
            done | sort -u)
          else
            passed=$(printf '%s\n' $rest | sort -u)
          fi
          if [ "$passed" != "$read_names" ]; then
            printf 'sync-env: the %s of %s passes\n%s\nbut sync.sh reads\n%s\n' \
              "$kind" "$host" "$passed" "$read_names" >&2
            status=1
          fi
        done <"$entries"
        [ -s "$entries" ] || { echo "sync-env: no host has rokokol.sync on" >&2; exit 1; }
        [ "$status" = 0 ] || exit 1
        touch "$out"
      '';

  # The pure half of yazi's own plugins, under plain Lua with yazi's globals stubbed
  yazi-plugin-tests =
    pkgs.runCommand "yazi-plugin-tests"
      {
        nativeBuildInputs = with pkgs; [ lua5_4 ];
        plugins = builtins.path {
          name = "huix-yazi-plugins";
          path = ./home-manager/programs/yazi/plugins;
        };
      }
      ''
        for test in "$plugins"/*/test.lua; do
          (cd "$(dirname "$test")" && lua test.lua)
        done
        touch "$out"
      '';
}
