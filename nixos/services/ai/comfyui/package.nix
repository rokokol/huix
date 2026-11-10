{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

# The package set, its CUDA nixpkgs and the node derivations come from nixified-ai; this file
# only names the nodes
let
  cfg = config.rokokol.comfyui;
in
{
  config = lib.mkIf cfg.enable {
    services.comfyui.customNodes =
      with inputs.nixified-ai.packages.${pkgs.stdenv.hostPlatform.system}.comfyui-nvidia.passthru.comfyuiPackages; [
        comfyui-kjnodes
        comfyui-gguf
        comfyui-impact-pack
        comfyui-impact-subpack
        comfyui-inpaint
        comfyui-controlnet-preprocessors
        comfyui-advanced-controlnet
        comfyui-pythongosssss-custom-scripts
        comfyui-sdxl-prompt-styler
        comfyui-essentials
        comfyui-comfyroll-custom_nodes
        comfyui-video-helper-suite
        comfyui-manager-animatediff-evolved
        comfyui-manager-ic-light-native
        comfyui-manager-easyillustrious
        comfyui-manager-kikotools
        # A1111 syntax, schedules, regional prompting and LoRA tags in the prompt. Its Makefile
        # runs `ruff format` as the default target, which the build environment lacks, and the
        # install phase only copies the tree, so the build step is skipped
        (comfyui-manager-prompt-control.overrideAttrs (_: {
          dontBuild = true;
        }))
        comfyui-manager-comfycouple
        comfyui-manager-lora-auto-trigger-words
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
}
