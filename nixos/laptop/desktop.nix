{ ... }:

{
  # Configure keymap in X11
  services.xserver = {
    enable = true;
    xkb = {
      layout = "us,ru";
      variant = "";
      options = "grp:shifts_toggle,ctrl:swapcaps";
    };
  };
}
