{
  lib,
  pkgs,
  inputs,
  ...
}:

{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  # sops-nix only decrypts at activation, through its own sops-install-secrets binary — it puts
  # nothing on PATH. Editing a file in secrets/ needs the CLIs
  environment.systemPackages = with pkgs; [
    age
    sops
  ];

  sops = {
    # builtins.path so the hash follows the secrets file, not every commit. A default, so a
    # host with secrets of its own can point at another file
    defaultSopsFile = lib.mkDefault (
      builtins.path {
        name = "huix-secrets";
        path = "${inputs.self}/secrets/secrets.yaml";
      }
    );

    # An age key, not sops.age.sshKeyPaths: a host key is regenerated on reinstall, and every
    # recipient change means re-encrypting the secrets. The desktops hold the owner's key, the
    # station its own (.sops.yaml). Keep it off /home: sops-nix decrypts secrets during early
    # activation, before a separate /home may be mounted. Back this file up — losing it means
    # re-encrypting the host's secrets file from scratch
    age.keyFile = "/var/lib/sops-nix/key.txt";
  };
}
