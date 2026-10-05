{ config, lib, ... }:

# The dictionary lives in rokokol/rofi-wooordhunt. Its mode names itself over rofi's script
# protocol, so the emoji belongs here and not in programs/rofi.nix with the display-* lines
lib.mkIf config.rokokol.hyprland.enable {
  programs.rofi-wooordhunt = {
    enable = true;
    prompt = "🤓";
  };
}
