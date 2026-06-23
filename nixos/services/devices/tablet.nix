{ pkgs, ... }:

{
  hardware.opentabletdriver = {
    enable = true;
    daemon.enable = true;
  };

  boot.kernelModules = [ "uinput" ];
  boot.blacklistedKernelModules = [ "hid-uclogic" ];

  # Скрыть ЛЮБОЙ физический графический планшет от libinput/Hyprland: курсором
  # рулит только виртуальный девайс OpenTabletDriver. Иначе сырой планшет летит
  # как mouse0 и дерётся с OTD за абсолютную позицию — курсор залипает, обычная
  # мышь перестаёт работать, клики пером пропадают. OTD читает планшет напрямую
  # через hidraw/usb, поэтому продолжает работать.
  #
  # Признак "настоящий планшет": ID_INPUT_TABLET=1 (udev так классифицирует перо)
  # И шина usb. Виртуалку OTD это не задевает — у неё нет ID_INPUT_TABLET, а шина
  # pci. VID:PID не зашит, поэтому правило ловит любой планшет (Wacom/Huion/...).
  #
  # Боковые кнопки планшета идут отдельным HID-интерфейсом, который udev видит как
  # ОБЫЧНУЮ КЛАВИАТУРУ (ID_INPUT_KEYBOARD=1, без ID_INPUT_TABLET) — генериком его
  # не возьмёшь, не убив настоящую клавиатуру. Поэтому pad прячем точечно по
  # VID:PID. Иначе кнопка двоит: firmware-хоткей от ядра + биндинг от OTD. После
  # этого кнопки идут только через OTD (он читает их по hidraw). Для нового
  # планшета с кнопками — дописать сюда строку с его 256c:006d из `lsusb`.
  services.udev.extraRules = ''
    SUBSYSTEM=="input", ENV{ID_INPUT_TABLET}=="1", ENV{ID_BUS}=="usb", ENV{LIBINPUT_IGNORE_DEVICE}="1"
    SUBSYSTEM=="input", ENV{ID_INPUT_KEYBOARD}=="1", ENV{ID_VENDOR_ID}=="256c", ENV{ID_MODEL_ID}=="006d", ENV{LIBINPUT_IGNORE_DEVICE}="1"
  '';
}
