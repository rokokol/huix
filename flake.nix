{
  description = "I love Monika btw";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";
    # Deliberately without nixpkgs.follows: nixvim pins its own nixpkgs and warns if you override it
    nixvim.url = "github:nix-community/nixvim";

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    ddlc-sddm-theme = {
      url = "github:rokokol/ddlc-sddm-theme";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.ddlc-palette.follows = "ddlc-palette";
    };

    ddlc-palette = {
      url = "github:rokokol/ddlc-palette";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ddlc-rofi-theme = {
      url = "github:rokokol/ddlc-rofi-theme";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.ddlc-palette.follows = "ddlc-palette";
    };

    ddlc-terminal-themes = {
      url = "github:rokokol/ddlc-themes";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.ddlc-palette.follows = "ddlc-palette";
    };

    ddlc-nvim = {
      url = "github:rokokol/ddlc.nvim";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.ddlc-palette.follows = "ddlc-palette";
    };

    ddlc-hyprlock = {
      url = "github:rokokol/ddlc-hyprlock";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.ddlc-palette.follows = "ddlc-palette";
    };

    hyprland-screen-shader = {
      url = "github:rokokol/hyprland-screen-shader";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # The compositor and both plugins below come from their own flakes, so every plugin is built
    # against the exact Hyprland revision it loads into; nixpkgs moves its plugins apart from its
    # compositor. This is the one input without a nixpkgs follows: Hyprland's cache holds builds
    # made from its own nixpkgs, and a follows would compile the compositor and the hypr* libs
    # here on every update. The three inputs move together, pinned only by the lock; when a
    # plugin does not build against the tip, hold Hyprland back in the lock with
    # `nix flake lock --override-input hyprland github:hyprwm/Hyprland/<rev>`
    hyprland.url = "github:hyprwm/Hyprland";

    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };

    hyprgrass = {
      url = "github:horriblename/hyprgrass";
      inputs.hyprland.follows = "hyprland";
    };

    # rofi's development branch, for the touch and click-to-exit support no release carries
    # yet (see WORKAROUNDS.md); the submodules are part of its source
    rofi = {
      url = "git+https://github.com/davatorium/rofi?ref=next&submodules=1";
      flake = false;
    };

    # compress.yazi's main branch: its last tag predates the fix for yazi 26 (see
    # WORKAROUNDS.md)
    compress-yazi = {
      url = "github:KKV9/compress.yazi";
      flake = false;
    };

    # wl-copy with --offer, from the branch of its pull request (see WORKAROUNDS.md)
    wl-clipboard-rs = {
      url = "github:rokokol/wl-clipboard-rs/wl-copy-multi-types";
      flake = false;
    };

    # which-key with 'langmap' support, from the branch of its pull request (see WORKAROUNDS.md)
    which-key-nvim = {
      url = "github:rokokol/which-key.nvim/langmap";
      flake = false;
    };

    claude-account = {
      url = "github:rokokol/claude-account";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rofi-wooordhunt = {
      url = "github:rokokol/rofi-wooordhunt";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    virtual-media-devices = {
      url = "github:rokokol/virtual-media-devices";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    skvpn = {
      url = "github:rokokol/skvpn";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    papers-skill = {
      url = "github:rokokol/papers-skill";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-best-practices = {
      url = "github:rokokol/nix-best-practices-skill";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    telegram-skill = {
      url = "github:rokokol/telegram-skill";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-matlab = {
      url = "gitlab:doronbehar/nix-matlab";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    freesmlauncher = {
      url = "github:FreesmTeam/FreesmLauncher";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      nixpkgs-stable,
      home-manager,
      nix-matlab,
      ...
    }@inputs:

    let
      system = "x86_64-linux";
      # Straight from nixpkgs, not from a host: nothing in nixpkgsConfig or the overlays
      # reaches the formatter or the checks, so picking a host would only make it look like
      # one owns them
      pkgs = nixpkgs.legacyPackages.${system};
      rokokolName = "rokokol";
      huixDir = "/home/${rokokolName}/huix";
      # Same on both hosts on purpose: absolute paths into the vault travel through Syncthing
      myWikiDir = "/home/${rokokolName}/myWiki";
      # Read by two modules that never meet: the XDG bookmarks and the sync unit's sweep
      projectsDir = "/home/${rokokolName}/Projects";

      # Nothing in this repo names a colour: hexes, their bare and rgba spellings and the two
      # terminal schemes all come from ddlc-palette, which reads them off ddlc.moe
      palette = inputs.ddlc-palette.lib.palette // {
        inherit (inputs.ddlc-palette.lib) bare rgba;
      };
      base16 = inputs.ddlc-palette.lib.base16;
      ruLayout = import ./lib/ru-layout.nix;
      # Milliseconds a key popup waits before it shows, in nixvim's which-key and in yazi alike;
      # which-key's own default, so a fast chord never flashes a popup
      whichKeyDelay = 200;

      commonArgs = {
        inherit
          base16
          huixDir
          inputs
          myWikiDir
          palette
          projectsDir
          rokokolName
          ruLayout
          system
          whichKeyDelay
          ;
      };

      # The palette is one node only because every ddlc-* input follows it. A forgotten
      # follows appears as a suffixed second node and as nothing else, and the colours then
      # diverge silently. This reads flake.lock as the JSON it is, forces no input and
      # reaches no network, so every rebuild and every `nix eval` asks it. A guard that
      # lives in CI answers after the work has left the machine
      paletteNodes = builtins.filter (n: builtins.match "ddlc-palette(_[0-9]+)?" n != null) (
        builtins.attrNames (builtins.fromJSON (builtins.readFile ./flake.lock)).nodes
      );

      nixpkgsConfig = {
        allowUnfree = true;
        # CUDA codegen target for this GPU (RTX 3060 = sm_86) — change on GPU swap
        cudaCapabilities = [ "8.6" ];
      };

      overlay-stable = _final: _prev: {
        stable = import nixpkgs-stable {
          inherit system;
          config = nixpkgsConfig;
        };
      };

      # The compositor, its portal and the two plugins come from their flakes, built against
      # one Hyprland revision; under the nixpkgs names, so programs.hyprland, the HM module,
      # xdg.portal and every script's PATH take them without a line each. hyprbars draws its
      # button icons with a hard-coded font (see WORKAROUNDS.md)
      overlay-hyprland = _final: prev: {
        inherit (inputs.hyprland.packages.${system}) hyprland xdg-desktop-portal-hyprland;
        hyprlandPlugins = prev.hyprlandPlugins // {
          hyprgrass = inputs.hyprgrass.packages.${system}.default;
          hyprbars = inputs.hyprland-plugins.packages.${system}.hyprbars.overrideAttrs (previous: {
            patches = (previous.patches or [ ]) ++ [ ./patches/hyprbars-icon-font.patch ];
          });
        };
      };

      # rofi from its development branch (see WORKAROUNDS.md). The wrapper and every plugin
      # take the unwrapped package from the overlay, so nothing else changes
      overlay-rofi = _final: prev: {
        rofi-unwrapped = prev.rofi-unwrapped.overrideAttrs {
          version = "2.0.0-unstable-${inputs.rofi.lastModifiedDate}";
          src = inputs.rofi;
          # The branch reports itself as 2.0.0-dev, not by the date the lock gives it
          preVersionCheck = "version=2.0.0-dev";
        };
      };

      # blueman connects a device on a raw double-click event, which a touchscreen never
      # produces; the patch moves that to the tree view's own activation (see WORKAROUNDS.md)
      overlay-blueman = _final: prev: {
        blueman = prev.blueman.overrideAttrs (previous: {
          patches = (previous.patches or [ ]) ++ [ ./patches/blueman-row-activated.patch ];
        });
      };

      # kitty's own copy of GLFW binds no wl_touch, so a finger does nothing in it; the patch
      # makes the first finger a click, a scroll or a selection (see WORKAROUNDS.md)
      overlay-kitty = _final: prev: {
        kitty = prev.kitty.overrideAttrs (previous: {
          patches = (previous.patches or [ ]) ++ [ ./patches/kitty-wayland-touch.patch ];
        });
      };

      # which-key reads the keys after a prefix itself, so 'langmap' never reaches them and a
      # Russian key finds only langmapper's hidden twins; the branch applies it (see WORKAROUNDS.md)
      overlay-which-key = _final: prev: {
        vimPlugins = prev.vimPlugins.extend (
          _: previous: {
            which-key-nvim = previous.which-key-nvim.overrideAttrs { src = inputs.which-key-nvim; };
          }
        );
      };

      # wl-copy offers one MIME type at a time, and a file manager has to offer two with different
      # data; the branch adds --offer, which yazi's clipboard calls by path (see WORKAROUNDS.md)
      overlay-wl-clipboard-rs = final: prev: {
        wl-clipboard-rs = prev.wl-clipboard-rs.overrideAttrs (previous: {
          version = "0.9.3-unstable-${inputs.wl-clipboard-rs.lastModifiedDate}";
          src = inputs.wl-clipboard-rs;
          # read from the branch's own lock, so no vendor hash goes stale on an input update
          cargoDeps = final.rustPlatform.importCargoLock {
            lockFile = "${inputs.wl-clipboard-rs}/Cargo.lock";
          };
          # the branch's tests live in the tools package, which a bare `cargo test` skips
          cargoTestFlags = previous.cargoBuildFlags;
        });
      };

      # yazi matches a key by the character it types, so the Russian layout misses every
      # binding, and its which popup lists every chord flat and at once; the patches add a
      # vim-style langmap, group labels with `[which] fold`, and `[which] delay`, all of which
      # the yazi module sets (see WORKAROUNDS.md). The delay patch applies on top of the groups
      overlay-yazi = _final: prev: {
        yazi-unwrapped = prev.yazi-unwrapped.overrideAttrs (previous: {
          patches = (previous.patches or [ ]) ++ [
            ./patches/yazi-langmap.patch
            ./patches/yazi-which-groups.patch
            ./patches/yazi-which-delay.patch
          ];
        });
        yaziPlugins = prev.yaziPlugins // {
          compress = prev.yaziPlugins.compress.overrideAttrs {
            version = "0.6-unstable-${inputs.compress-yazi.lastModifiedDate}";
            src = inputs.compress-yazi;
          };
          relative-motions = prev.yaziPlugins.relative-motions.overrideAttrs (previous: {
            patches = (previous.patches or [ ]) ++ [ ./patches/relative-motions-ya-emit.patch ];
          });
        };
      };

      mkHost =
        {
          configuration,
          home,
          overlays,
        }:
        nixpkgs.lib.nixosSystem {
          specialArgs = commonArgs;
          modules = [
            configuration
            inputs.virtual-media-devices.nixosModules.default
            inputs.skvpn.nixosModules.default
            inputs.telegram-skill.nixosModules.default

            {
              nixpkgs.hostPlatform = system;
              nixpkgs.config = nixpkgsConfig;
              nixpkgs.overlays = overlays;
            }

            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "bak";
                sharedModules = [
                  inputs.zen-browser.homeModules.default
                  inputs.hyprland-screen-shader.homeModules.default
                  inputs.rofi-wooordhunt.homeModules.default
                  inputs.ddlc-rofi-theme.homeModules.default
                  inputs.claude-account.homeModules.default
                  inputs.virtual-media-devices.homeModules.default
                  inputs.papers-skill.homeModules.default
                ];

                extraSpecialArgs = commonArgs;

                users.${rokokolName} = import home;
              };
            }
          ];
        };
    in
    assert
      paletteNodes == [ "ddlc-palette" ]
      || throw "flake.lock holds ${builtins.concatStringsSep ", " paletteNodes} — an input is missing its ddlc-palette.follows";
    {
      nixosConfigurations.nixos-pc = mkHost {
        configuration = ./nixos/configuration-pc.nix;
        home = ./home-manager/home-pc.nix;
        overlays = [
          overlay-stable
          overlay-hyprland
          overlay-rofi
          overlay-yazi
          overlay-which-key
          overlay-wl-clipboard-rs
          nix-matlab.overlay
        ];
      };

      nixosConfigurations.nixos-laptop = mkHost {
        configuration = ./nixos/configuration-laptop.nix;
        home = ./home-manager/home-laptop.nix;
        overlays = [
          overlay-stable
          overlay-hyprland
          overlay-rofi
          overlay-blueman
          overlay-kitty
          overlay-yazi
          overlay-which-key
          overlay-wl-clipboard-rs
        ];
      };

      formatter.${system} = pkgs.nixfmt-tree;

      # nix flake check already evaluates both hosts. The nixvim entries add the one thing
      # evaluation cannot say: whether the Lua nixvim assembles out of every module is
      # parseable — nixvim runs stylua over the generated init.lua, so a syntax error fails
      # the build.
      # nix-lint holds every .nix file here to the standard the skill carries. It runs in a
      # build sandbox, so it leaves out the rules that need this flake's inputs; the eval
      # job runs the whole checker through apps.check-nix, where the inputs are there
      checks.${system} =
        nixpkgs.lib.mapAttrs' (
          name: cfg:
          nixpkgs.lib.nameValuePair "nixvim-init-${name}"
            cfg.config.home-manager.users.${rokokolName}.programs.nixvim.build.initFile
        ) inputs.self.nixosConfigurations
        // {
          nix-lint = inputs.nix-best-practices.lib.mkCheck {
            inherit pkgs;
            root = ./.;
            namespaces = [ "rokokol" ];
          };

          # The scripts against stubbed commands: every keyword rotate-screen.sh and
          # tablet-mode.sh emit is asserted here, where there is no compositor to ask
          script-tests =
            pkgs.runCommand "script-tests"
              {
                nativeBuildInputs = with pkgs; [ jq ];
                scripts = builtins.path {
                  name = "huix-scripts";
                  path = ./scripts;
                };
              }
              ''
                bash "$scripts/tests/run.sh"
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
        };

      # `nix run .#check-nix -- -N rokokol` — the whole checker, pinned by flake.lock rather
      # than looked up at the moment a job runs
      apps.${system} = {
        check-nix = {
          type = "app";
          program = nixpkgs.lib.getExe inputs.nix-best-practices.packages.${system}.check-nix;
          meta.description = "Hold this repository to the standard nix-best-practices carries";
        };

        # `nix run .#drv-diff` — both hosts and every check, here and at another revision
        drv-diff = {
          type = "app";
          program = nixpkgs.lib.getExe inputs.nix-best-practices.packages.${system}.drv-diff;
          meta.description = "Say whether a change moved any derivation this flake builds";
        };
      };
    };
}
