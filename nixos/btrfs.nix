{ config, lib, ... }:

# hardware-configuration.nix regenerates, so btrfs options cannot live there. btrfs takes
# compress for the whole volume from the subvolume that mounts first, hence every point
{
  options.rokokol.btrfs.mounts = lib.mkOption {
    type = lib.types.listOf lib.types.nonEmptyStr;
    default = [ ];
    example = [
      "/"
      "/home"
    ];
    description = "Mount points of a btrfs volume that take compression and drop atime";
  };

  config.fileSystems = lib.genAttrs config.rokokol.btrfs.mounts (_: {
    options = [
      "compress=zstd"
      "noatime"
    ];
  });
}
