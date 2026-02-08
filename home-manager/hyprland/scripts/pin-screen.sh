#!/usr/bin/env bash

# 1. Получаем геометрию (белый полупрозрачный фон, тонкая рамка)
GEOM=$(slurp -b ffffff66 -w 1 -f "%x %y %w %h")
[ -z "$GEOM" ] && exit 0

# 2. Парсим координаты через read (быстрее и чище)
read -r X Y W H <<< "$GEOM"

# 3. Создаем временный файл
FILE="/tmp/pin_$(date +%s).png"

# 4. Делаем скриншот (исправлен синтаксис -g)
grim -g "$X,$Y ${W}x${H}" "$FILE"

# 5. Запускаем просмотрщик в фоне
(
  # Форсируем локаль, чтобы не было ошибки с точкой/запятой
  LC_NUMERIC=C swayimg \
    --class="desktop-pin" \
    --config="general.position=$X,$Y" \
    --config="general.size=$W,$H" \
    "$FILE" 
  
  # Удаляем файл после закрытия окна
  rm -f "$FILE"
)
