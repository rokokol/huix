{ pkgs, rokokolName, ... }:

# Embedded / hardware-hacking toolchain for both hosts. Covers the parts you
# actually flash at workshops: Arduino/AVR, ESP32/ESP8266, STM32/ARM (SWD/JTAG
# + DFU) and RP2040/Pico.
#
# udev: platformio-core.udev ships the canonical, board-spanning rule set
# (CP210x, CH340, FTDI, ST-Link 0483:*, RP2040 2e8a:*, DFU bootloaders, AVR
# programmers) with MODE=0666, so probes and bootloaders are usable without
# root and without extra rules. The dialout group covers generic /dev/ttyUSB*
# /dev/ttyACM* serial access (Serial Monitor, esptool, avrdude over UART).

{
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

    # STM32 / ARM (SWD/JTAG + DFU)
    openocd
    stlink
    dfu-util
    gcc-arm-embedded # arm-none-eabi GCC toolchain

    # RP2040 / Raspberry Pi Pico
    picotool

    # Serial console + USB inspection (universal)
    picocom
    usbutils
  ];

  users.users.${rokokolName} = {
    extraGroups = [
      "dialout"
      "input"
    ];
  };
}
