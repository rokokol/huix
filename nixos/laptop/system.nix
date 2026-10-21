{ rokokolName, ... }:

{
  networking.hostName = "nixos-laptop";

  # Docker and skvpn-restore order after network-online.target, and uwsm waits for graphical.target.
  # A slow Wi-Fi start then holds the login for the full 60 s timeout. Both start without a network.
  systemd.services.NetworkManager-wait-online.enable = false;

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
