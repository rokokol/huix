{ pkgs, ... }:

let
  # the plugin resolves <desktop-id>.tap only inside its own libexec, so xarchiver's wrapper has to be planted there
  thunar-archive-plugin-xarchiver = pkgs.thunar-archive-plugin.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      ln -s ${pkgs.xarchiver}/libexec/thunar-archive-plugin/xarchiver.tap $out/libexec/thunar-archive-plugin/
    '';
  });
in
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
    selectdefaultapplication
    thunar
    thunar-archive-plugin-xarchiver
    thunar-media-tags-plugin
    thunar-volman
    unar
    unzip
    xarchiver
    xfce4-exo
    zip
  ];
}
