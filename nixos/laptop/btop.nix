{ pkgs, ... }:

{
  # to forse btop show intel gpu
  security.wrappers.btop = {
    owner = "root";
    group = "root";
    permissions = "u+rx,g+rx,o+rx";
    setuid = true;
    source = "${pkgs.btop}/bin/btop";
  };
}
