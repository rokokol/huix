{
  inputs,
  rokokolName,
  ...
}:

{
  imports = [ inputs.comfyui-nix.nixosModules.default ];

  services.comfyui = {
    enable = true;
    gpuSupport = "cuda";
    enableManager = true;
    port = 8188;
    listenAddress = "127.0.0.1";
    dataDir = "/home/${rokokolName}/comfyui-data";
    user = rokokolName;
    group = "users";
    createUser = false;
    openFirewall = false;
    extraArgs = [
      "--lowvram"
    ];
  };

  nix.settings = {
    substituters = [
      "https://comfyui.cachix.org"
    ];

    trusted-public-keys = [
      "comfyui.cachix.org-1:33mf9VzoIjzVbp0zwj+fT51HG0y31ZTK3nzYZAX0rec="
    ];
  };
}
