_:

# The plugin lives in github:rokokol/archive-mount.yazi. Its module owns the plugin, the setup
# subscription and the tools the plugin runs. The FUSE helper stays the system's: a store copy
# would hide it on PATH
{
  programs.archive-mount-yazi.enable = true;
}
