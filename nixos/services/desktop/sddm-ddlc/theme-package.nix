# Деривация DDLC-темы для SDDM (Qt6, Theme-API 2.0).
# QML-файлы именуются в CamelCase — это требование QML (имя файла задаёт имя
# типа), сознательное исключение из общего правила kebab-case в репозитории.
{ stdenvNoCC, imagemagick, inputs }:

let
  # Стикеры берутся из общих ассетов репозитория (корень флейка в сторе)
  stickers = "${inputs.self}/assets/ddlc-stickers";
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

    # Все стикеры лежат в PNG (Qt6 в greeter без qtimageformats не читает
    # webp) — просто копируем: обычные, обрезанные (-cut) и искажённые
    cp ${stickers}/*-sticker-*.png "$theme/assets/"

    # Картинка меню «Just Monika» из игры — для окошек пасхалки
    cp ${stickers}/just-monika-ok.png "$theme/assets/"

    # Тайл серого шума для зернистости фона
    magick -size 240x240 xc:gray50 +noise Random -colorspace Gray "$theme/assets/noise.png"

    runHook postInstall
  '';
}
