_:

{
  # Essential for Intel
  services.thermald.enable = true;
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";

      # The Wacom digitizer carries both the pen and the touchscreen. Autosuspended after two
      # idle seconds, it drops the first pen and touch events while it wakes up, which reads as a
      # pen that starts to track late. It stays awake; a USB HID device draws far below the
      # noise of anything else on the battery
      USB_DENYLIST = "056a:50d0";
    };
  };
}
