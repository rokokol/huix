# The lock screen and Monika's dialog live in rokokol/ddlc-hyprlock; the seam is the font it
# ships none of and the shader it flashes the screen with. The dialog is on by default — the
# laptop opts out in home-laptop.nix — and hypridle.nix reads ddlc.hyprlock.lockCommand
{
  config,
  inputs,
  ...
}:

{
  imports = [ inputs.ddlc-hyprlock.homeManagerModules.default ];

  ddlc.hyprlock = {
    enable = true;
    font = "Doki";
    screenShader = config.programs.screen-shader.package;
  };
}
