{ pkgs, rokokolName, ... }:

# Toolchain for embedded / hardware tinkering on both hosts. Covers what you
# actually flash at workshops: Arduino/AVR, ESP32/ESP8266, STM32/ARM
# (SWD/JTAG + DFU) and RP2040/Pico
#
# udev: platformio-core.udev ships a canonical set of rules for a pile of boards
# (CP210x, CH340, FTDI, ST-Link 0483:*, RP2040 2e8a:*, DFU bootloaders, AVR
# programmers) with MODE=0666, so probes and bootloaders work without root and
# without extra rules. The dialout group gives shared access to /dev/ttyUSB*
# /dev/ttyACM* (Serial Monitor, esptool, avrdude over UART)

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

    # Meshtastic (LoRa-mesh: Heltec / LILYGO and other ESP32 boards) — a CLI
    # for flashing configuration and accessing the node over serial/BLE.
    # stable: on unstable meshtastic pulls in python3.14-pandas-stubs, whose
    # tests fail under pytest 9 (deprecation → error). On stable (python 3.13,
    # old pytest) it builds fine
    stable.meshtastic

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
}
