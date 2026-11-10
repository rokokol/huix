{
  config,
  lib,
  pkgs,
  inputs,
  rokokolName,
  ...
}:

# nixified-ai owns the ComfyUI package set, its CUDA nixpkgs and the node packages; this module
# supplies the host policy only
{
  imports = [ inputs.nixified-ai.nixosModules.comfyui ];

  options.rokokol.comfyui = {
    enable = lib.mkEnableOption "ComfyUI with declarative custom nodes";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8188;
      description = "Loopback port ComfyUI binds";
    };

    publicPort = lib.mkOption {
      type = lib.types.port;
      default = 8189;
      description = "Tailnet port ComfyUI publishes";
    };
  };

  config = lib.mkIf config.rokokol.comfyui.enable {
    services.comfyui = {
      enable = true;
      user = "comfyui";
      group = "comfyui";
      acceleration = "cuda";
      host = "127.0.0.1";
      # StateDirectory would put the state under /var/lib/private, whose mode systemd holds at 0700
      # and refuses to start with anything else; /srv keeps the same tree writable for the owner by
      # group, with no root and no touch of a system directory (see DEVIATIONS.md)
      home = "/srv/comfyui";
      inherit (config.rokokol.comfyui) port;
      # No ComfyUI-Manager: core imports comfyui_manager in main.py before any custom node loads,
      # and this package set ships it as a separate Python package rather than in ComfyUI's env
      customNodes =
        with inputs.nixified-ai.packages.${pkgs.stdenv.hostPlatform.system}.comfyui-nvidia.passthru.comfyuiPackages; [
          comfyui-kjnodes
          comfyui-gguf
          comfyui-impact-pack
          comfyui-controlnet-preprocessors
          comfyui-pythongosssss-custom-scripts
          comfyui-sdxl-prompt-styler
          comfyui-essentials
          comfyui-comfyroll-custom_nodes
          comfyui-advanced-controlnet
          comfyui-video-helper-suite
          comfyui-manager-animatediff-evolved
          comfyui-manager-ic-light-native
          comfyui-manager-easyillustrious
          comfyui-manager-kikotools
          # The skill's front end: A1111 syntax, regional prompting and LoRA tags in the prompt
          # Upstream's Makefile runs `ruff format` as its default target, which their derivation does not
          # provide; the install phase copies the tree and needs no build
          (comfyui-manager-prompt-control.overrideAttrs (_: {
            dontBuild = true;
          }))
          comfyui-manager-comfycouple
          comfyui-manager-lora-auto-trigger-words
          comfyui-impact-subpack
          comfyui-inpaint
          # Samplers beyond the core list, and the utility packs the workflow uses
          comfyui-res4lyf
          comfyui-manager-euler-smea-dyn-sampler
          comfyui-manager-extra-samplers
          comfyui-manager-ab-samplercustom
          comfyui-manager-ksamplertimer
          comfyui-rgthree
          comfyui-crystools
          comfyui-easy-use
          comfyui-inspire-pack
          comfyui-comfy-mtb
        ];
    };

    users.groups.comfyui = { };
    users.users.comfyui.group = "comfyui";

    users.users.${rokokolName}.extraGroups = [ "comfyui" ];

    # The service writes with UMask 0077 and owns the state, so the owner needs the group bit
    # to add models by hand; this rule and the override below are the only places that widen it
    systemd.tmpfiles.settings."10-comfyui" = {
      "/srv/comfyui".d = {
        user = "comfyui";
        group = "comfyui";
        mode = "2770";
      };
      "/home/${rokokolName}/comfyui-data" = {
        "L+" = {
          argument = "/srv/comfyui";
        };
      };
    };

    systemd.services.comfyui.serviceConfig = {
      UMask = lib.mkForce "0007";
      StateDirectory = lib.mkForce [ ];
      PrivateUsers = lib.mkForce false;
    };

    environment.sessionVariables = {
      COMFYUI_PORT = toString config.rokokol.comfyui.port;
    };

    rokokol.tailnet-web.sites.comfyui = {
      port = config.rokokol.comfyui.publicPort;
      backend = "http://127.0.0.1:${toString config.rokokol.comfyui.port}";
      extraConfig = ''
        client_max_body_size 512m;
        proxy_read_timeout 900s;
      '';
    };
  };
}
