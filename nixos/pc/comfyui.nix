{
  config,
  inputs,
  ...
}:

let
  homeDir = config.users.users.rokokol.home;
in
{
  imports = [ inputs.comfyui-nix.nixosModules.default ];

  services.comfyui = {
    enable = true;
    gpuSupport = "cuda";
    enableManager = true;
    port = 8188;
    listenAddress = "127.0.0.1";
    dataDir = "${homeDir}/comfyui-data";
    user = "rokokol";
    group = "users";
    createUser = false;
  };
}
