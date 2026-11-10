# ComfyUI

An image and video generator driven by a node graph, running on the PC with CUDA and published to the tailnet

The package, the node set and the CUDA build of Torch come from the `nixified-ai` input, because nixpkgs builds Torch without CUDA and its wheels disagree on the CUDA version across `torch`, `torchvision` and `torchaudio`. The files here set host policy only: the user, the port and the node list

## Where things live

| What | Where |
| --- | --- |
| State, models, outputs | `/var/lib/comfyui`, a symlink to `/var/lib/private/comfyui` |
| Nodes from the config | `/nix/store/…-comfyui-wrapped/lib/python3.14/site-packages/custom_nodes` |
| Nodes installed by hand | `/var/lib/comfyui/.local/share/comfyui/custom_nodes` |

The state directory is the module's own `StateDirectory`. systemd keeps it under `/var/lib/private`, whose mode is `0700 root`, so adding a model needs root:

```sh
sudo install -m 0644 -o comfyui -g comfyui ~/Downloads/model.safetensors \
  /var/lib/comfyui/.local/share/comfyui/models/checkpoints/
```

`install` sets the owner, the group and the mode in one step. A plain `sudo cp` leaves the file owned by root, and the service reads it only while the mode lets others read

## Node manager

There is none. ComfyUI core imports `comfyui_manager` in `main.py` before any custom node loads, and the `nixified-ai` set keeps that package outside the ComfyUI environment, so `--enable-manager` only logs a warning and clears the flag. Nodes are listed in `package.nix` instead of installed through the interface

## Nodes

| Package | What it adds |
| --- | --- |
| `comfyui-kjnodes` | conditions, math, conditioning work, graph utilities |
| `comfyui-gguf` | loading of quantised GGUF models and LoRA |
| `comfyui-impact-pack` | `FaceDetailer`, `DetailerForEach`, SEGS, `MaskToSEGS` |
| `comfyui-impact-subpack` | `bbox` detectors, `ultralytics` among them |
| `comfyui-inpaint` | `INPAINT_*` nodes: masks, blur, padding for a local repair |
| `comfyui-controlnet-preprocessors` | ControlNet preprocessors: pose, depth, lineart |
| `comfyui-advanced-controlnet` | ControlNet control by step and by mask |
| `comfyui-pythongosssss-custom-scripts` | autocomplete, snippets, interface improvements |
| `comfyui-sdxl-prompt-styler` | prompt style templates for SDXL-like models |
| `comfyui-essentials` | small image and mask utilities |
| `comfyui-comfyroll-custom_nodes` | helper nodes for pipelines and animation |
| `comfyui-video-helper-suite` | video assembly and splitting, frame handling |
| `comfyui-manager-animatediff-evolved` | animation and temporal nodes |
| `comfyui-manager-ic-light-native` | relighting: a new light direction and colour on an existing image |
| `comfyui-manager-easyillustrious` | presets and a character database for Illustrious XL |
| `comfyui-manager-kikotools` | autocomplete of embeddings, LoRA names and tags inside the prompt field |
| `comfyui-manager-prompt-control` | A1111 prompt syntax, schedules, regional prompting, LoRA tags in the text |
| `comfyui-manager-comfycouple` | two figures side by side without their features blending |
| `comfyui-manager-lora-auto-trigger-words` | reads a LoRA's trigger words from the model file |
| `comfyui-res4lyf` | `ClownSampler` and the `beta57` and `kl_optimal` schedulers |
| `comfyui-manager-euler-smea-dyn-sampler` | the `euler_smea_dy` sampler, for SDXL-like latents only |
| `comfyui-manager-extra-samplers` | further samplers and schedulers |
| `comfyui-manager-ab-samplercustom` | A/B comparison of samplers |
| `comfyui-manager-ksamplertimer` | time per step, for measuring a sampler |
| `comfyui-rgthree` | `Power Lora Loader`, seed and context control |
| `comfyui-crystools` | VRAM and RAM monitor, metadata, node bypass |
| `comfyui-easy-use` | lazy loaders and utilities |
| `comfyui-inspire-pack` | global seed, image utilities |
| `comfyui-comfy-mtb` | text and debugging nodes: string slicing, regex, console output |

`prompt-control` is built with `dontBuild`. Its `Makefile` default target runs `ruff format`, which the build environment lacks, and the install phase only copies the tree, so no build step is needed

## Models

Files are placed in the matching directory under `models/` by hand, and the service lists them on the next request

| Model | Source |
| --- | --- |
| Anima base, turbo, text encoder and VAE | <https://huggingface.co/circlestone-labs/Anima> |
| WAI Illustrious v7.0 | <https://huggingface.co/IbarakiDouji/WAI-NSFW-illustrious-SDXL> |
| Face and hand detectors | <https://huggingface.co/Bingsu/adetailer> |
| Real-ESRGAN upscalers | <https://github.com/xinntao/Real-ESRGAN/releases> |
| SAM ViT-B for exact masks | <https://dl.fbaipublicfiles.com/segment_anything/sam_vit_b_01ec64.pth> |

## Access

The service listens on `127.0.0.1:8188` and is published as `rokokol.tailnet-web.sites.comfyui` on port `8189`. nginx admits tailnet addresses only, so a local name or a LAN address gets `403`

## Checks

```sh
nix eval --raw .#nixosConfigurations.nixos-pc.config.services.comfyui.package.outPath
curl -sS http://127.0.0.1:8188/system_stats
curl -sS http://127.0.0.1:8188/object_info | jq 'keys | length'
```

The first resolves the package, the second answers once the service is up, the third prints the number of node classes
