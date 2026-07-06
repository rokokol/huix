{
  govnoDir,
  lib,
  rokokolName,
  ...
}:

{
  networking.hostName = "nixos-pc";
  users.users.${rokokolName}.description = "sigma pro";

  fileSystems."${govnoDir}" = {
    device = lib.mkForce "/dev/disk/by-label/govno";
    fsType = "ntfs3";
    options = [
      "rw" # Read & Write
      "uid=1000" # rokokol's id
      "gid=100" # rokokol's group id
      "umask=0022" # Access roules (0755 for dirs, 0644 for files)
      "nofail" # Do not break system if fails
      "windows_names" # Do not break ntfs
    ];
  };
}
