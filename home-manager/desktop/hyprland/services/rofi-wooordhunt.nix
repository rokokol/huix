{ ... }:

# The dictionary lives in rokokol/rofi-wooordhunt. Its mode names itself over rofi's script
# protocol, so the emoji belongs here and not in programs/rofi.nix with the display-* lines
{
  programs.rofi-wooordhunt = {
    enable = true;
    prompt = "🤓";
  };
}
