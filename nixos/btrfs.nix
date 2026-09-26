{
  config,
  lib,
  pkgs,
  rokokolName,
  ...
}:

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

  config = {
    fileSystems = lib.genAttrs config.rokokol.btrfs.mounts (_: {
      options = [
        "compress=zstd"
        "noatime"
      ];
    });

    # What a compressed file really takes shows in yazi's spot window, and only compsize can
    # tell: the btrfs search it runs needs root. It reads extent metadata and no file contents
    security.sudo.extraRules = lib.mkIf (config.rokokol.btrfs.mounts != [ ]) [
      {
        users = [ rokokolName ];
        commands = [
          {
            command = lib.getExe pkgs.compsize;
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };
}
