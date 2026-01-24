{ pkgs, ... }:

{
  # X11 & GNOME
  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Раскладка клавиатуры
  services.xserver.xkb = {
    layout = "us,ru";
    variant = "";
    options = "grp:win_space_toggle";
  };

  # Portals (apps & system interaction)
  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gnome
      pkgs.xdg-desktop-portal-gtk
    ];
    config.common.default = [ "gnome" "gtk" ];
  };

  # fonts
  fonts.packages = with pkgs; [
    (stdenv.mkDerivation {
      name = "my-fonts";
      src = ../fonts;
      installPhase = ''
        mkdir -p $out/share/fonts/truetype
        mkdir -p $out/share/fonts/opentype
        find $src -name "*.ttf" -exec cp {} $out/share/fonts/truetype/ \;
        find $src -name "*.otf" -exec cp {} $out/share/fonts/opentype/ \;
      '';
    })
  ];
}

