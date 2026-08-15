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
      url = "github:rokokol/ddlc-terminal-themes";
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
      govnoDir = "/home/${rokokolName}/govno";
      # Same on both hosts on purpose: absolute paths into the vault travel through Syncthing
      myWikiDir = "/home/${rokokolName}/myWiki";

      # Nothing in this repo names a colour: hexes, their bare and rgba spellings and the two
      # terminal schemes all come from ddlc-palette, which reads them off ddlc.moe
      palette = inputs.ddlc-palette.lib.palette // {
        inherit (inputs.ddlc-palette.lib) bare rgba;
      };
      base16 = inputs.ddlc-palette.lib.base16;

      commonArgs = {
        inherit
          base16
          govnoDir
          huixDir
          inputs
          myWikiDir
          palette
          rokokolName
          system
          ;
      };

      nixpkgsConfig = {
        allowUnfree = true;
        # CUDA codegen target for this GPU (RTX 3060 = sm_86) — change on GPU swap
        cudaCapabilities = [ "8.6" ];
      };

      overlay-stable = final: prev: {
        stable = import nixpkgs-stable {
          inherit system;
          config = nixpkgsConfig;
        };
      };

      # SDL3 dlopens the appindicator lib for tauon's tray, but nixpkgs keeps it off the
      # wrapper's LD_LIBRARY_PATH (see workarounds.md)
      overlay-tauon = final: prev: {
        tauon = prev.tauon.overrideAttrs (old: {
          makeWrapperArgs = old.makeWrapperArgs ++ [
            "--prefix LD_LIBRARY_PATH : ${prev.lib.makeLibraryPath [ prev.libayatana-appindicator ]}"
          ];
        });
      };

      # under structuredAttrs nixpkgs never expands the "$out" in jupyterlab's JUPYTERLAB_DIR
      # (see workarounds.md)
      overlay-jupyterlab = final: prev: {
        pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
          (pyfinal: pyprev: {
            jupyterlab = pyprev.jupyterlab.overrideAttrs (_: {
              makeWrapperArgs = [
                "--set"
                "JUPYTERLAB_DIR"
                "${builtins.placeholder "out"}/share/jupyter/lab"
              ];
            });
          })
        ];
      };

      # No cache serves a CUDA torch: cache.nixos.org builds it CPU-only and cuda-maintainers
      # has nothing for cudaPackages_13, which comfyui demands. torch-bin is the official
      # PyTorch wheel with CUDA already inside — fetched, never compiled. torch-bin itself has
      # to be overridden, not just aliased to torch: torchvision-bin and torchaudio-bin name it
      # directly, and leaving it on the default cudaPackages drags in a second CUDA stack
      overlay-torch-bin = final: prev: {
        pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
          (pyfinal: pyprev: {
            # torch 2.12 wants cuda-bindings >= 13.0.3 and marks itself broken below that
            cuda-bindings = pyprev.cuda-bindings.override { cudaPackages = final.cudaPackages_13; };
            torch-bin =
              (pyprev.torch-bin.override { cudaPackages = final.cudaPackages_13; }).overrideAttrs
                (old: {
                  # the wheel pins setuptools<82 against nixpkgs' 83 (see workarounds.md)
                  pythonRelaxDeps = (old.pythonRelaxDeps or [ ]) ++ [ "setuptools" ];
                });
            # nixpkgs points torchaudio at a cu128 wheel while torch is cu130, and torchaudio
            # refuses to import across that gap (see workarounds.md)
            torchaudio-bin = pyprev.torchaudio-bin.overrideAttrs (_: {
              src = final.fetchurl {
                name = "torchaudio-2.11.0+cu130-cp314-cp314-linux_x86_64.whl";
                url = "https://download.pytorch.org/whl/cu130/torchaudio-2.11.0%2Bcu130-cp314-cp314-manylinux_2_28_x86_64.whl";
                hash = "sha256-N4tJZxtYERSi0l1Ako8SoVCHL+rfEWaaY/Vz6Bx4AZo=";
              };
            });
            torch = pyfinal.torch-bin;
            torchaudio = pyfinal.torchaudio-bin;
            torchvision = pyfinal.torchvision-bin;
          })
        ];
      };

      # hyprland 0.56.1 doesn't build against nixpkgs' glaze 8.0.0, so pin it back to 7.2.0
      # (see workarounds.md)
      overlay-hyprland = final: prev: {
        hyprland = prev.hyprland.override {
          glaze = prev.glaze.overrideAttrs (_: {
            version = "7.2.0";
            src = prev.fetchFromGitHub {
              owner = "stephenberry";
              repo = "glaze";
              tag = "v7.2.0";
              hash = "sha256-f3NVRi3SXKo42hn0WCw7JsOK3EkdOVJIcuzhPorKjFY=";
            };
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
                ];

                extraSpecialArgs = commonArgs;

                users.${rokokolName} = import home;
              };
            }
          ];
        };
    in
    {
      nixosConfigurations.nixos-pc = mkHost {
        configuration = ./nixos/configuration-pc.nix;
        home = ./home-manager/home-pc.nix;
        overlays = [
          overlay-hyprland
          overlay-jupyterlab
          overlay-stable
          overlay-tauon
          # PC only: the laptop has no GPU to spend 3 GiB of CUDA wheels on
          overlay-torch-bin
          nix-matlab.overlay
        ];
      };

      nixosConfigurations.nixos-laptop = mkHost {
        configuration = ./nixos/configuration-laptop.nix;
        home = ./home-manager/home-laptop.nix;
        overlays = [
          overlay-hyprland
          overlay-jupyterlab
          overlay-stable
          overlay-tauon
          nix-matlab.overlay
        ];
      };

      # Straight from nixpkgs, not from a host: nothing in nixpkgsConfig or the overlays
      # reaches this package, so picking a host would only make it look like one owns it
      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-tree;

      # nix flake check already evaluates both hosts. This adds the one thing evaluation
      # cannot say: whether the Lua nixvim assembles out of every module is parseable —
      # nixvim runs stylua over the generated init.lua, so a syntax error fails the build
      checks.${system} = nixpkgs.lib.mapAttrs' (
        name: cfg:
        nixpkgs.lib.nameValuePair "nixvim-init-${name}"
          cfg.config.home-manager.users.${rokokolName}.programs.nixvim.build.initFile
      ) inputs.self.nixosConfigurations;
    };
}
