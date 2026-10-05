{
  config,
  lib,
  pkgs,
  rokokolName,
  ...
}:

# Embedded toolchain for Arduino/AVR, ESP32, STM32, RP2040
# platformio-core.udev ships udev rules for common programmers/bootloaders; dialout grants
# /dev/ttyUSB* /dev/ttyACM* access
{
  options.rokokol.embedded.enable =
    lib.mkEnableOption "the embedded toolchain and its udev rules"
    // {
      default = config.rokokol.workstation.enable;
    };

  config = lib.mkIf config.rokokol.embedded.enable {
    services.udev.packages = with pkgs; [
      platformio-core.udev
    ];

    environment.systemPackages = with pkgs; [
      # Arduino / AVR
      platformio
      arduino-cli
      avrdude

      # ESP32 / ESP8266
      esptool

      # Meshtastic (LoRa-mesh: Heltec / LILYGO and other ESP32 boards) — a CLI
      # for flashing configuration and accessing the node over serial/BLE
      meshtastic

      # STM32 / ARM (SWD/JTAG + DFU)
      openocd
      stlink
      dfu-util
      gcc-arm-embedded # arm-none-eabi GCC toolchain

      # RP2040 / Raspberry Pi Pico
      picotool

      # Serial console + USB inspection (general-purpose)
      picocom
      usbutils
    ];

    users.users.${rokokolName} = {
      extraGroups = [
        "dialout"
        "input"
      ];
    };
  };
}
