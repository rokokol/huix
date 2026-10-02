{ ... }:

{
  imports = [
    ./desktop/user.nix
    ./programs/default.nix
  ];

  rokokol = {
    packages.laptop = true;

    hyprland = {
      enable = true;
      # A broken EDID leaves only the kernel's fallback modes, and preferred then takes the
      # first of them, 640x480; highres takes the biggest
      monitorMode = "highres";
      touchpadNaturalScroll = true;
      lidNoSleep = true;
      tabletMode = true;
      titlebars = true;
      touchGestures = true;
    };

    waybar = {
      enable = true;
      shader = true;
      backlight = true;
      battery = true;
      launcher = true;
      virtKeyboard = true;
      swap = true;
      layoutKeyboard = "at-translated-set-2-keyboard";
    };
  };

  # The dialog costs two shell-spawning labels at 10 Hz plus a render loop — not on battery
  ddlc.hyprlock.dialog = false;

  # A finger wants something on the bar to press even when no shader is on
  programs.screen-shader.waybar.idleIcon = true;

  # The built-in pen is mapped to the built-in panel: with nothing said, Hyprland stretches a
  # tablet over every monitor, so an external screen would take half of the digitizer
  wayland.windowManager.hyprland.settings.device = {
    name = "wacom-pen-and-multitouch-sensor-pen";
    output = "eDP-1";
  };

  # Only the built-in panel is scaled; an external screen keeps the default scale of 1
  wayland.windowManager.hyprland.settings.monitor = [
    {
      output = "eDP-1";
      mode = "preferred";
      position = "auto";
      scale = 1.33;
    }
  ];

  # Forwards AVRCP commands from Bluetooth headphones (tap, wear sensor) to MPRIS players
  services.mpris-proxy.enable = true;

  # Files
  home.file.".octaverc".text = ''
    PS1('>> ');
    # disable octave warning
    warning('off', 'Octave:graphics-toolkit-gnuplot');
  '';
}
