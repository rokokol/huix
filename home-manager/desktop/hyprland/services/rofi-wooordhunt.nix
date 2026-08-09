{ config, lib, ... }:

# The modi itself lives in github:rokokol/rofi-wooordhunt. Enabling it brings the SUPER+Y
# bind and names its own rofi mode — huix only says when. Its default wrap widths already
# match the 720px window from programs/rofi/theme.nix, so they stay unset here
{
  config = lib.mkIf config.rokokol.hyprland.enable {
    programs.rofi-wooordhunt = {
      enable = true;
      prompt = "🤓";
    };
  };
}
