{ rokokolName, ... }:

{
  networking.hostName = "nixos-laptop";
  users.users.${rokokolName}.description = rokokolName;

  programs.ssh.knownHosts.nixos-pc.publicKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII93jfv+9KCDTZtIS7SqLqmuiE9eih140NqUgn7tloGd";

  nix = {
    distributedBuilds = true;
    settings.builders-use-substitutes = true;
    buildMachines = [
      {
        hostName = "nixos-pc";
        protocol = "ssh-ng";
        sshUser = rokokolName;
        sshKey = "/home/${rokokolName}/.ssh/id_ed25519";
        systems = [ "x86_64-linux" ];
        maxJobs = 4;
        speedFactor = 4;
        supportedFeatures = [
          "benchmark"
          "kvm"
          "nixos-test"
        ];
        mandatoryFeatures = [ "big-parallel" ];
      }
    ];
  };
}
