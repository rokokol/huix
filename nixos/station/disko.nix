{ inputs, ... }:

# The whole disk, as the installer creates it and as the system mounts it. The btrfs options
# are set here and not in rokokol.btrfs.mounts: both write fileSystems.<path>.options, and the
# lists would join into each option twice. The backup volume is nofail, so a dead backup
# partition does not stop the boot; the restic server does not start without it
{
  imports = [ inputs.disko.nixosModules.disko ];

  # A scrub reads each block and compares it with its checksum. One disk holds no second
  # copy, so a scrub finds a bad block and cannot repair it: the unit fails, and alerts.nix
  # mails that
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [
      "/"
      "/srv/backup"
    ];
  };

  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/disk/by-id/ata-KINGSTON_SUV400S37120G_50026B726605FC01";
    content = {
      type = "gpt";
      partitions = {
        esp = {
          priority = 1;
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };

        system = {
          priority = 2;
          size = "40G";
          content = {
            type = "btrfs";
            extraArgs = [ "-f" ];
            # btrfs takes compress for the whole volume from the subvolume that mounts first,
            # so each one carries it
            subvolumes =
              builtins.mapAttrs
                (_: mountpoint: {
                  inherit mountpoint;
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                })
                {
                  "@root" = "/";
                  "@home" = "/home";
                  "@nix" = "/nix";
                };
          };
        };

        backup = {
          priority = 3;
          size = "100%";
          # btrfs for its data checksums: this host holds no repository key, so restic cannot
          # check the data here, and a scrub is the only way to find a rotten block. No
          # compression: the nodes compress and then encrypt, so nothing is left to gain
          content = {
            type = "btrfs";
            extraArgs = [ "-f" ];
            mountpoint = "/srv/backup";
            mountOptions = [
              "nofail"
              "noatime"
            ];
          };
        };
      };
    };
  };
}
