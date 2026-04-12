{ pkgs, ... }:

{
  services = {
    gvfs.enable = true;
    tumbler.enable = true;
    udisks2.enable = true;
  };

  environment.systemPackages = with pkgs; [
    dosfstools
    exfatprogs
    ffmpegthumbnailer
    libgsf
    ntfs3g
    p7zip
    poppler
    thunar
    thunar-archive-plugin
    thunar-volman
    unar
    unzip
    xfce4-exo
    zip
  ];
}
