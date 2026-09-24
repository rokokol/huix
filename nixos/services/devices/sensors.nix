{ config, lib, ... }:

{
  options.rokokol.sensors.enable = lib.mkEnableOption "the accelerometer and the other IIO sensors, through iio-sensor-proxy";

  config = lib.mkIf config.rokokol.sensors.enable {
    hardware.sensor.iio.enable = true;
  };
}
