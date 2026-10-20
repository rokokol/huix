{ config, lib, ... }:

# envfs serves /bin and /usr/bin from the PATH of the calling process, so a script or a plugin
# that hardcodes /bin/bash or /usr/bin/python3 finds the binary instead of failing with ENOENT
{
  options.rokokol.envfs.enable = lib.mkEnableOption "envfs for hardcoded /bin and /usr/bin paths" // {
    default = config.rokokol.workstation.enable;
  };

  config = lib.mkIf config.rokokol.envfs.enable {
    services.envfs.enable = true;
  };
}
