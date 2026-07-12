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

  # Web Serial API в Chromium требует uaccess/seat-теги на устройстве, иначе
  # port.open() виснет навечно (sandbox проверяет не только file permissions).
  # platformio-core.udev ставит MODE=0666, но uaccess не всегда — добавляем
  # явно для типичных Meshtastic / ESP32-плат (CP210x, CH34x, ESP32-S3 native USB).
  services.udev.extraRules = ''
    SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", MODE="0666", TAG+="uaccess", TAG+="udev-acl"
    SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="7523", MODE="0666", TAG+="uaccess", TAG+="udev-acl"
    SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="55d4", MODE="0666", TAG+="uaccess", TAG+="udev-acl"
    SUBSYSTEM=="tty", ATTRS{idVendor}=="303a", MODE="0666", TAG+="uaccess", TAG+="udev-acl"
  '';

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
