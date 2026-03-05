#!/usr/bin/env bash

get_normal() {
  awk -v seed="$RANDOM" -v m="$1" -v s="$2" 'BEGIN {
        srand(seed);
        u1 = rand(); u2 = rand();
        z = sqrt(-2 * log(u1)) * cos(2 * 3.1415926535 * u2);
        printf "%.0f", m + z * s
    }'
}

WALLPAPER_DIR="$HOME/myWiki/media"
TEMP_COLLAGE="/tmp/swww_collage.jpg"
BG_COLOR="#282828" # ImageMagick bg
SWWW_BG="282828"   # swww bg (without #)
TRANSITIONS=("fade" "left" "right" "top" "bottom" "wipe" "wave" "grow" "random" "outer")

# Check swww
if ! swww query >/dev/null 2>&1; then
  swww-daemon &
  sleep 1
fi

RES_W=1920
RES_H=1080
WORK_W=1200

while true; do
  NUM_PICS=$((RANDOM % 4 + 1))

  # Do not touch subdirs if nixos-pc
  FIND_OPTS=()
  if [ "$(hostname)" != "nixos-pc" ]; then
    FIND_OPTS+=("-maxdepth" "1")
  fi

  # Only static images
  mapfile -d $'\0' SELECTED_PICS < <(find "$WALLPAPER_DIR" "${FIND_OPTS[@]}" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) -print0 | shuf -z -n "$NUM_PICS")

  if [ ${#SELECTED_PICS[@]} -eq 0 ]; then
    echo "Cannot find images (*≧m≦*)"
    sleep 30
    continue
  fi

  RANDOM_TRANS=${TRANSITIONS[$RANDOM % ${#TRANSITIONS[@]}]}

  # Collage
  CMD=("magick" "-size" "${RES_W}x${RES_H}" "xc:${BG_COLOR}")
  SEGMENT_WIDTH=$((WORK_W / NUM_PICS))

  for i in "${!SELECTED_PICS[@]}"; do
    IMG="${SELECTED_PICS[$i]}"
    ANG=$(get_normal 0 12)

    BASE_X=$((i * SEGMENT_WIDTH + SEGMENT_WIDTH / 2))
    REL_X=$((BASE_X - WORK_W / 2))
    SIGMA_X=$((SEGMENT_WIDTH * 2 / 3))

    JITTER_X=$(($(get_normal 0 $SIGMA_X) % (SEGMENT_WIDTH / 2) - (SEGMENT_WIDTH / 4)))
    OFFSET_X=$((REL_X + JITTER_X))

    MAX_Y=$((RES_H / 2 - 350))
    [ "$MAX_Y" -lt 50 ] && MAX_Y=50
    SIGMA_Y=$((MAX_Y / 3))
    OFFSET_Y=$(($(get_normal 0 $SIGMA_Y) % (MAX_Y * 2) - MAX_Y))

    # Cords for ImageMagick
    if [ "$OFFSET_X" -ge 0 ]; then OFFSET_X="+${OFFSET_X}"; fi
    if [ "$OFFSET_Y" -ge 0 ]; then OFFSET_Y="+${OFFSET_Y}"; fi
    OFF="${OFFSET_X}${OFFSET_Y}"

    CMD+=("(")
    CMD+=("${IMG}[0]" "-resize" "800x800>" "-bordercolor" "#3c3836" "-border" "8" "-background" "none" "-rotate" "$ANG") # image
    CMD+=("(" "+clone" "-background" "black" "-shadow" "50x10+15+15" ")")                                                # shadow
    CMD+=("+swap" "-background" "none" "-layers" "merge")                                                                # swap shadow & image layers
    CMD+=(")")
    CMD+=("-gravity" "center" "-geometry" "$OFF" "-composite")
  done

  CMD+=("$TEMP_COLLAGE")
  "${CMD[@]}"

  swww img "$TEMP_COLLAGE" --resize fit --fill-color "$SWWW_BG" --transition-type "$RANDOM_TRANS" --transition-step 90

  sleep 3
done
