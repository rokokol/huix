# Деривация DDLC-темы для SDDM (Qt6, Theme-API 2.0).
# QML-файлы именуются в CamelCase — это требование QML (имя файла задаёт имя
# типа), сознательное исключение из общего правила kebab-case в репозитории.
{ stdenvNoCC, imagemagick }:

let
  # Стикеры берутся из общих ассетов репозитория
  stickers = ../../../../assets/ddlc-stickers;
in
stdenvNoCC.mkDerivation {
  pname = "sddm-ddlc-theme";
  version = "1.0";

  src = ./theme;

  nativeBuildInputs = [ imagemagick ];

  installPhase = ''
    runHook preInstall

    theme=$out/share/sddm/themes/ddlc
    mkdir -p "$theme/assets"
    cp -r ./. "$theme/"

    # Qt6 в greeter без qtimageformats не читает webp —
    # конвертируем стикеры в PNG прямо на этапе сборки
    for f in ${stickers}/*-sticker-*.webp; do
      magick "$f" "$theme/assets/$(basename "$f" .webp).png"
    done

    # Искажённые спрайты Юри уже в PNG — просто копируем
    cp ${stickers}/*-distorted-*.png "$theme/assets/"

    # Картинка меню «Just Monika» из игры — для окошек пасхалки
    cp ${stickers}/just-monika-ok.png "$theme/assets/"

    # Тайл серого шума для зернистости фона
    magick -size 240x240 xc:gray50 +noise Random -colorspace Gray "$theme/assets/noise.png"

    runHook postInstall
  '';
}
