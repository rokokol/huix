{
  config,
  lib,
  pkgs,
  inputs,
  modulesPath,
  ...
}:

# A console-only installer image whose store already holds the system it installs and the disko
# program for its disk, so the install needs no network and no store in RAM. It holds no secret:
# make-station-iso.sh adds them to a copy, and install-station.sh, run by the unit below, does
# the rest. Every fact about the installed system comes from the target's own configuration
let
  target = config.rokokol.station-installer.target.config;
  disks = lib.attrValues target.disko.devices.disk;
  disko = target.system.build.destroyFormatMount;
  scriptsDir = "${inputs.self}/scripts";

  # The two files the installer runs, and nothing else from the directory: an edit to another
  # script must not rebuild the image
  scripts = builtins.path {
    name = "station-installer-scripts";
    path = scriptsDir;
    filter =
      path: _:
      builtins.elem (lib.removePrefix "${scriptsDir}/" path) [
        "install-station.sh"
        "lib"
        "lib/station-secrets.sh"
      ];
  };

  installer = pkgs.writeShellApplication {
    name = "install-station";
    runtimeInputs = [
      config.nix.package
      config.system.build.nixos-install
      pkgs.bashInteractive
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
      pkgs.gnutar
      pkgs.systemd
      pkgs.util-linux
    ];
    runtimeEnv = {
      STATION_DISK = (lib.head disks).device;
      STATION_DISKO = "${disko}/bin/disko-destroy-format-mount";
      STATION_ROOT = target.disko.rootMountPoint;
      STATION_SYSTEM = "${target.system.build.toplevel}";
      STATION_KEY_PATH = target.sops.age.keyFile;
      # The StateDirectory= of the tailscaled.service that the tailscale package ships
      STATION_TAILSCALE_DIR = "/var/lib/tailscale";
    };
    text = ''exec ${lib.getExe pkgs.bash} ${scripts}/install-station.sh "$@"'';
  };
in
{
  imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];

  options.rokokol.station-installer.target = lib.mkOption {
    type = lib.types.raw;
    description = "The NixOS system the image installs, as nixosSystem returns it";
  };

  config = {
    assertions = [
      {
        assertion = lib.length disks == 1;
        message = "The station installer erases one disk, and the target declares ${toString (lib.length disks)}";
      }
    ];

    # The volume ID takes the edition, which names the image apart from a stock installer
    isoImage.edition = "station";
    isoImage.storeContents = [
      target.system.build.toplevel
      disko
    ];

    # The station has no ZFS, and the module would put a kernel module and its tools in the
    # image; the installer profile only defaults it on
    boot.supportedFilesystems.zfs = false;
    documentation.enable = false;

    # tty1 belongs to the installer: its countdown reads keys there, and a refusal leaves a shell
    # there. A getty on tty1 hangs the terminal up and ends both. getty.target and logind start
    # it as autovt@tty1, an alias of getty@tty1, so both names are switched off. The other
    # consoles keep the image's own login
    systemd.services."getty@tty1".enable = false;
    systemd.services."autovt@tty1".enable = false;

    systemd.services.station-install = {
      description = "Install ${target.networking.hostName} onto ${(lib.head disks).device}";
      wantedBy = [ "multi-user.target" ];
      # nixos-install copies from the image's store, which this unit registers in the database
      after = [ "register-nix-paths.service" ];
      requires = [ "register-nix-paths.service" ];
      serviceConfig = {
        # idle waits for the boot to finish, so its messages do not run into the countdown
        Type = "idle";
        ExecStart = lib.getExe installer;
        StandardInput = "tty-force";
        StandardOutput = "tty";
        TTYPath = "/dev/tty1";
        TTYReset = true;
        TTYVHangup = true;
      };
    };
  };
}
