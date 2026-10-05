_:

# 3.7 GiB of RAM cannot back the 50G tmpfs the shared boot module asks for, for the reason
# nixos/laptop/boot.nix gives. /tmp stays on the system volume and is swept at boot
{
  boot.tmp = {
    useTmpfs = false;
    cleanOnBoot = true;
  };
}
