{ inputs, ... }:

# The station decrypts only its own file, encrypted to its own key and the owner's. A secret
# from the desktops' file is not in it, and sops-nix fails the build for a missing key
{
  sops.defaultSopsFile = builtins.path {
    name = "huix-station-secrets";
    path = "${inputs.self}/secrets/station.yaml";
  };
}
