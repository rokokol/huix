{
  config,
  lib,
  pkgs,
  rokokolName,
  huixDir,
  ...
}:

let
  virtual-cam = pkgs.writeShellApplication {
    name = "virtual-cam";
    runtimeInputs = with pkgs; [
      ffmpeg
      file
      v4l-utils
    ];
    text = ''
      exec bash "${huixDir}/scripts/virtual-cam.sh" "$@"
    '';
  };
in
{
  options.rokokol.virtualCamera.enable = lib.mkEnableOption "virtual webcam (v4l2loopback)";

  config = lib.mkIf config.rokokol.virtualCamera.enable {
    # Virtual webcam: v4l2loopback creates /dev/video10, into which any source
    # (ffmpeg, OBS) writes frames while applications see it as a regular camera.
    # Feeding a looped video/image is done with the `virtual-cam` command
    boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
    boot.kernelModules = [ "v4l2loopback" ];

    # exclusive_caps=1 is needed so the device is detected as a camera by browsers/messengers
    boot.extraModprobeConfig = ''
      options v4l2loopback devices=1 video_nr=10 card_label="Virtual Camera" exclusive_caps=1
    '';

    environment.systemPackages = [
      virtual-cam
      pkgs.v4l-utils
    ];

    users.users.${rokokolName} = {
      extraGroups = [
        "video"
      ];
    };
  };
}
