{ config, inputs, ... }:

# The lock screen and Monika's dialog live in rokokol/ddlc-hyprlock; the seam is the font it
# ships none of and the shader it flashes the screen with. The dialog is on by default — the
# laptop opts out in home-laptop.nix — and hypridle.nix reads ddlc.hyprlock.lockCommand
# screenShader already implies flash = "screen-shader", so setting flash here would only
# undo it. The layout is one attrset in the module, which also computes the engine's wrap
# width from it — nudging it through programs.hyprlock.settings splits that in two
{
  imports = [ inputs.ddlc-hyprlock.homeModules.default ];

  ddlc.hyprlock = {
    enable = true;
    font = "Doki";
    screenShader = config.programs.screen-shader.package;
  };
}
