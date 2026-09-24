_:

# 8 GiB of RAM cannot back the 50G tmpfs the shared boot module asks for: tmpfs grows on
# write, so the kernel swaps and then kills a process instead of returning ENOSPC. A /tmp
# on disk keeps no such promise, and it needs the boot sweep that tmpfs gave for free
{
  boot.tmp = {
    useTmpfs = false;
    cleanOnBoot = true;
  };
}
