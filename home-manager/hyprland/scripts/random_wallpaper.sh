#!/usr/bin/env bash

WALLPAPER_DIR="$HOME/myWiki/media"
TEMP_COLLAGE="/tmp/swww_collage.jpg"
ROW1="/tmp/swww_row1.jpg"
ROW2="/tmp/swww_row2.jpg"
SWWW_BG="282828" # Цвет фона по краям экрана (Gruvbox)

TRANSITIONS=("fade" "left" "right" "top" "bottom" "wipe" "wave" "grow" "center" "outer")

if ! swww query >/dev/null 2>&1; then
  swww-daemon &
  sleep 1
fi

while true; do
  NUM_PICS=$((RANDOM % 4 + 1))

  # Ищем файлы только в корне папки
  mapfile -d $'\0' SELECTED_PICS < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) -print0 | shuf -z -n "$NUM_PICS")

  if [ ${#SELECTED_PICS[@]} -eq 0 ]; then
    sleep 30
    continue
  fi

  RANDOM_TRANS=${TRANSITIONS[$RANDOM % ${#TRANSITIONS[@]}]}

  # Если попадается гифка — показываем её одну на весь экран
  HAS_GIF=false
  for img in "${SELECTED_PICS[@]}"; do
    if [[ "${img,,}" == *.gif ]]; then
      HAS_GIF=true
      GIF_FILE="$img"
      break
    fi
  done

  if [ "$HAS_GIF" = true ]; then
    swww img "$GIF_FILE" --resize fit --fill-color "$SWWW_BG" --transition-type "$RANDOM_TRANS" --transition-step 90
    sleep 30
    continue
  fi

  if [ "$NUM_PICS" -eq 1 ]; then
    swww img "${SELECTED_PICS[0]}" --resize fit --fill-color "$SWWW_BG" --transition-type "$RANDOM_TRANS" --transition-step 90
  else
    # Умная "плиточная" склейка без обрезки и искажений

    if [ "$NUM_PICS" -eq 2 ]; then
      # Ставим бок о бок, подогнав под одну высоту (например, 1080px)
      # x1080 означает: высота 1080, ширину вычислить пропорционально
      magick "${SELECTED_PICS[0]}[0]" -resize x1080 "${SELECTED_PICS[1]}[0]" -resize x1080 +append "$TEMP_COLLAGE"

    elif [ "$NUM_PICS" -eq 3 ]; then
      # Верхний ряд: две картинки бок о бок
      magick "${SELECTED_PICS[0]}[0]" -resize x1080 "${SELECTED_PICS[1]}[0]" -resize x1080 +append "$ROW1"
      # Склеиваем верхний ряд и третью картинку по вертикали, подогнав под одну ширину (1920px)
      # 1920x означает: ширина 1920, высоту вычислить пропорционально
      magick "$ROW1" -resize 1920x "${SELECTED_PICS[2]}[0]" -resize 1920x -append "$TEMP_COLLAGE"

    elif [ "$NUM_PICS" -eq 4 ]; then
      # Верхний ряд (2 картинки)
      magick "${SELECTED_PICS[0]}[0]" -resize x1080 "${SELECTED_PICS[1]}[0]" -resize x1080 +append "$ROW1"
      # Нижний ряд (2 картинки)
      magick "${SELECTED_PICS[2]}[0]" -resize x1080 "${SELECTED_PICS[3]}[0]" -resize x1080 +append "$ROW2"
      # Соединяем ряды по вертикали, выровняв их ширину
      magick "$ROW1" -resize 1920x "$ROW2" -resize 1920x -append "$TEMP_COLLAGE"
    fi

    # Вписываем готовый монолитный блок в экран (--resize fit предотвращает обрезку блока)
    swww img "$TEMP_COLLAGE" --resize fit --fill-color "$SWWW_BG" --transition-type "$RANDOM_TRANS" --transition-step 90
  fi

  sleep 30
done
