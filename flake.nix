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

      commonArgs = {
        inherit
          base16
          huixDir
          inputs
          myWikiDir
          palette
          projectsDir
          rokokolName
          system
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
          nix-matlab.overlay
        ];
      };

      nixosConfigurations.nixos-laptop = mkHost {
        configuration = ./nixos/configuration-laptop.nix;
        home = ./home-manager/home-laptop.nix;
        overlays = [
          overlay-stable
          nix-matlab.overlay
        ];
      };

      # Straight from nixpkgs, not from a host: nothing in nixpkgsConfig or the overlays
      # reaches this package, so picking a host would only make it look like one owns it
      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-tree;

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
            pkgs = nixpkgs.legacyPackages.${system};
            root = ./.;
            namespaces = [ "rokokol" ];
          };
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
