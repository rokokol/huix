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
      inputs.ddlc-themes.follows = "ddlc-themes";
    };

    ddlc-palette = {
      url = "github:rokokol/ddlc-palette";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ddlc-rofi-theme = {
      url = "github:rokokol/ddlc-rofi-theme";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.ddlc-palette.follows = "ddlc-palette";
      inputs.ddlc-themes.follows = "ddlc-themes";
    };

    ddlc-themes = {
      url = "github:rokokol/ddlc-themes";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.ddlc-palette.follows = "ddlc-palette";
    };

    ddlc-nvim = {
      url = "github:rokokol/ddlc.nvim";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.ddlc-palette.follows = "ddlc-palette";
      inputs.ddlc-themes.follows = "ddlc-themes";
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

    # The head of hyprwm/hyprland-plugins#715, until it is merged (see WORKAROUNDS.md)
    hyprland-plugins = {
      url = "github:LionHeartP/hyprland-plugins/e606588d590c301ec37244b55109ea6d9eb17e2c";
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

    archive-mount-yazi = {
      url = "github:rokokol/archive-mount.yazi";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    rename-case-yazi = {
      url = "github:rokokol/rename-case.yazi";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
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

    hermes-agent = {
      url = "github:NousResearch/hermes-agent/v0.22.5";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
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

    kdenlive-mcp = {
      url = "github:crom-org/kdenlive-mcp-plus";
      flake = false;
    };

    freecad-mcp = {
      url = "github:neka-nat/freecad-mcp/v0.1.27";
      flake = false;
    };

    dav-mcp = {
      url = "github:PhilflowIO/dav-mcp/v5.0.0";
      flake = false;
    };

    blender-mcp = {
      url = "github:ahujasid/blender-mcp";
      flake = false;
    };

    audacity-mcp = {
      url = "github:xDarkzx/Audacity-MCP";
      flake = false;
    };

    rea = {
      url = "github:morluto/rea/rea-agents-6.8.0";
      flake = false;
    };

    anatomy = {
      url = "github:wheresryan22/anatomy";
      flake = false;
    };

    opus-sound-layer = {
      url = "github:Bodila51/opus-sound-layer";
      flake = false;
    };

    pyloudnorm = {
      url = "github:csteinmetz1/pyloudnorm";
      flake = false;
    };

    remotion-skills = {
      url = "github:remotion-dev/skills";
      flake = false;
    };

    ex-ussr-kinship-research = {
      url = "github:DenisSergeevitch/ex-ussr-kinship-research";
      flake = false;
    };

    # Every input named skill-NAME is one skill, and home-manager/programs/agents/skills.nix gives
    # each to the agents as NAME. A skill that comes with a service is the service flake's own
    # input instead, as mail-skill, telegram-skill and papers-skill are
    skill-3x-ui-admin = {
      url = "github:rokokol/3x-ui-admin-skill";
      flake = false;
    };
    skill-ai-commit-trailers = {
      url = "github:rokokol/ai-commit-trailers-skill";
      flake = false;
    };
    skill-bash-best-practices = {
      url = "github:rokokol/bash-best-practices-skill";
      flake = false;
    };
    skill-ci = {
      url = "github:rokokol/ci-skill";
      flake = false;
    };
    skill-close-session = {
      url = "github:rokokol/close-session-skill";
      flake = false;
    };
    skill-code-comments = {
      url = "github:rokokol/code-comments-skill";
      flake = false;
    };
    skill-contributing = {
      url = "github:rokokol/contributing-skill";
      flake = false;
    };
    skill-create-readme = {
      url = "github:rokokol/create-readme-skill";
      flake = false;
    };
    skill-headless-gui = {
      url = "github:rokokol/headless-gui-skill";
      flake = false;
    };
    skill-huix-standard = {
      url = "github:rokokol/huix-standard-skill";
      flake = false;
    };
    skill-maintainer-docs = {
      url = "github:rokokol/maintainer-docs-skill";
      flake = false;
    };
    # A flake, unlike the rest: checks.nix and the check-nix app take its checker from it
    skill-nix-best-practices = {
      url = "github:rokokol/nix-best-practices-skill";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    skill-obsidian-cli = {
      url = "github:rokokol/obsidian-cli-skill";
      flake = false;
    };
    skill-phone-alert = {
      url = "github:rokokol/phone-alert-skill";
      flake = false;
    };
    skill-skill-authoring = {
      url = "github:rokokol/skill-authoring-skill";
      flake = false;
    };
    skill-super-productivity = {
      url = "github:rokokol/super-productivity-skill";
      flake = false;
    };
    skill-termux-api = {
      url = "github:rokokol/termux-api-skill";
      flake = false;
    };
    skill-tests = {
      url = "github:rokokol/tests-skill";
      flake = false;
    };
    skill-versioning = {
      url = "github:rokokol/versioning-skill";
      flake = false;
    };

    telegram-skill = {
      url = "github:rokokol/telegram-skill";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mail-skill = {
      url = "github:rokokol/mail-skill";
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

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    freesmlauncher = {
      url = "github:FreesmTeam/FreesmLauncher";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # A NixOS module and nothing else: it has no inputs, so it needs no follows
    nix-flatpak.url = "github:gmodena/nix-flatpak";
  };

  outputs =
    { nixpkgs, nix-matlab, ... }@inputs:

    let
      system = "x86_64-linux";
      # Straight from nixpkgs, not from a host: nothing in nixpkgsConfig or the overlays
      # reaches the formatter or the checks, so picking a host would only make it look like
      # one owns them
      pkgs = nixpkgs.legacyPackages.${system};
      rokokolName = "rokokol";
      # The address of the owner's commits; Forgejo links a commit to its account by it
      rokokolEmail = "git@rokokol.art";
      huixDir = "/home/${rokokolName}/huix";
      # Same on every host on purpose: absolute paths into the vault travel through Syncthing
      myWikiDir = "/home/${rokokolName}/myWiki";
      # Read by two modules that never meet: the XDG bookmark p opens the first segment, and the
      # sync unit's sweep walks every segment, joined by colons into PROJECTS_DIR
      projectsDirs = [ "/home/${rokokolName}/Projects" ];

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
      # Degrees Celsius of the CPU from which waybar and the station's dashboard both show alarm
      criticalTemperature = 80;

      commonArgs = {
        inherit
          base16
          criticalTemperature
          huixDir
          inputs
          myWikiDir
          palette
          projectsDirs
          rokokolEmail
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

      # Every file in overlays/ is one overlay, named after the file; a host picks the ones it
      # wants by that name
      overlays = nixpkgs.lib.mapAttrs' (
        file: _:
        nixpkgs.lib.nameValuePair (nixpkgs.lib.removeSuffix ".nix" file) (
          import ./overlays/${file} (commonArgs // { inherit nixpkgsConfig; })
        )
      ) (builtins.readDir ./overlays);

      mkHost = import ./lib/mk-host.nix { inherit commonArgs nixpkgsConfig; };
    in
    assert
      paletteNodes == [ "ddlc-palette" ]
      || throw "flake.lock holds ${builtins.concatStringsSep ", " paletteNodes} — an input is missing its ddlc-palette.follows";
    {
      nixosConfigurations.nixos-pc = mkHost {
        configuration = ./nixos/configuration-pc.nix;
        home = ./home-manager/home-pc.nix;
        overlays = [
          overlays.stable
          overlays.hyprland
          overlays.rofi
          overlays.yazi
          overlays.which-key
          overlays.wl-clipboard-rs
          overlays.dav-mcp
          overlays.freecad-mcp
          overlays.kdenlive-mcp
          overlays.blender-mcp
          overlays.audacity-mcp
          overlays.rea
          nix-matlab.overlay
        ];
      };

      nixosConfigurations.nixos-laptop = mkHost {
        configuration = ./nixos/configuration-laptop.nix;
        home = ./home-manager/home-laptop.nix;
        overlays = [
          overlays.stable
          overlays.hyprland
          overlays.rofi
          overlays.blueman
          overlays.kitty
          overlays.yazi
          overlays.which-key
          overlays.wl-clipboard-rs
          overlays.dav-mcp
          overlays.freecad-mcp
        ];
      };

      # Headless: built on the PC and pushed with --target-host, so it never evaluates this
      # flake itself
      nixosConfigurations.nixos-station = mkHost {
        configuration = ./nixos/configuration-station.nix;
        home = ./home-manager/home-station.nix;
        overlays = [
          overlays.yazi
          overlays.which-key
          overlays.dav-mcp
        ];
      };

      formatter.${system} = pkgs.nixfmt-tree;

      checks.${system} = import ./checks.nix (commonArgs // { inherit pkgs; });

      # `nix develop -c bash scripts/tests/run.sh` — the script tests by hand, with the tools the
      # check gives them, taken from the check rather than listed twice
      devShells.${system}.default = pkgs.mkShell {
        inputsFrom = [ inputs.self.checks.${system}.script-tests ];
      };

      # Built only when asked: `nix flake check` evaluates a package and builds only checks. The
      # VM tests and the image each take minutes and gigabytes, too much for every check run
      packages.${system} = {
        station-boot-test = import ./nixos/station/tests/boot.nix (commonArgs // { inherit pkgs; });

        # The installer image without its secrets; scripts/make-station-iso.sh adds them
        station-installer =
          nixpkgs.lib.addMetaAttrs
            {
              description = "Installer image that erases the station's disk and installs nixos-station";
              license = nixpkgs.lib.licenses.mit;
            }
            (import ./nixos/station/installer/mk-image.nix commonArgs {
              target = inputs.self.nixosConfigurations.nixos-station;
            }).config.system.build.isoImage;

        station-install-test = import ./nixos/station/tests/install.nix (commonArgs // { inherit pkgs; });
      };

      # `nix run .#check-nix -- -N rokokol` — the whole checker, pinned by flake.lock rather
      # than looked up at the moment a job runs
      apps.${system} = {
        check-nix = {
          type = "app";
          program = nixpkgs.lib.getExe inputs.skill-nix-best-practices.packages.${system}.check-nix;
          meta.description = "Hold this repository to the standard nix-best-practices carries";
        };

        # `nix run .#drv-diff` — every host and every check, here and at another revision
        drv-diff = {
          type = "app";
          program = nixpkgs.lib.getExe inputs.skill-nix-best-practices.packages.${system}.drv-diff;
          meta.description = "Say whether a change moved any derivation this flake builds";
        };

        # `nix run .#make-station-iso -- write ISO OUTPUT` — the station's image with its secrets
        # added, with xorriso from the lock rather than from the shell's PATH
        make-station-iso = {
          type = "app";
          program = nixpkgs.lib.getExe (
            import ./nixos/station/installer/make-iso.nix { inherit pkgs inputs; }
          );
          meta.description = "Copy the station's installer image with its secrets added inside";
        };
      };
    };
}
