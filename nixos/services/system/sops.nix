{ pkgs, inputs, ... }:

{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  # sops-nix only decrypts at activation, through its own sops-install-secrets binary — it puts
  # nothing on PATH. Editing secrets/secrets.yaml needs the CLIs
  environment.systemPackages = with pkgs; [
    age
    sops
  ];

  sops = {
    # builtins.path so the hash follows the secrets file, not every commit
    defaultSopsFile = builtins.path {
      name = "huix-secrets";
      path = "${inputs.self}/secrets/secrets.yaml";
    };

    # A personal age key, not sops.age.sshKeyPaths: a host key is regenerated on reinstall,
    # and every recipient change means re-encrypting the secrets. Keep it off /home: sops-nix
    # decrypts secrets during early activation, before a separate /home may be mounted.
    # Back this file up — losing it means re-encrypting secrets/secrets.yaml from scratch
    age.keyFile = "/var/lib/sops-nix/key.txt";
  };
}
