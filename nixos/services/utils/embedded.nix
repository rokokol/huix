{ pkgs, rokokolName, ... }:

# Тулчейн для embedded / ковыряния железа на обоих хостах. Покрывает то, что
# реально прошиваешь на воркшопах: Arduino/AVR, ESP32/ESP8266, STM32/ARM
# (SWD/JTAG + DFU) и RP2040/Pico.
#
# udev: platformio-core.udev несёт канонический набор правил на кучу плат
# (CP210x, CH340, FTDI, ST-Link 0483:*, RP2040 2e8a:*, DFU-загрузчики, AVR-
# программаторы) с MODE=0666, так что пробники и загрузчики работают без root и
# без лишних правил. Группа dialout даёт общий доступ к /dev/ttyUSB*
# /dev/ttyACM* (Serial Monitor, esptool, avrdude по UART).

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

    # Meshtastic (LoRa-mesh: Heltec / LILYGO и прочие ESP32-платы) — CLI
    # для прошивки конфигурации и доступа к ноде по serial/BLE.
    meshtastic
    meshtastic-web

    # STM32 / ARM (SWD/JTAG + DFU)
    openocd
    stlink
    dfu-util
    gcc-arm-embedded # arm-none-eabi GCC toolchain

    # RP2040 / Raspberry Pi Pico
    picotool

    # Serial-консоль + осмотр USB (универсальное)
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
