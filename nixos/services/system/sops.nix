{
  inputs,
  pkgs,
  rokokolName,
  ...
}:

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

    # A personal age key, not sops.age.sshKeyPaths: neither host runs sshd, so there is no
    # /etc/ssh/ssh_host_ed25519_key to derive a recipient from. Back this file up — losing it
    # means re-encrypting secrets/secrets.yaml from scratch
    age.keyFile = "/home/${rokokolName}/.config/sops/age/keys.txt";
  };
}
