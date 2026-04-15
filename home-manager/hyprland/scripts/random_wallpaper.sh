#!/usr/bin/env bash

set -euo pipefail

get_normal() {
  awk -v seed="$RANDOM" -v m="$1" -v s="$2" 'BEGIN {
        srand(seed);
        u1 = rand(); u2 = rand();
        z = sqrt(-2 * log(u1)) * cos(2 * 3.1415926535 * u2);
        printf "%.0f", m + z * s
    }'
}

WALLPAPER_DIR="$HOME/myWiki/media"
TEMP_COLLAGE="/tmp/awww_collage.jpg"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/awww"
BG_COLOR="#282828" # ImageMagick bg
AWWW_BG="282828"   # awww bg (without #)
TRANSITIONS=("left" "right")

mkdir -p "$CACHE_DIR"

# Check awww
if ! awww query >/dev/null 2>&1; then
  awww-daemon -q >/dev/null 2>&1 &
  sleep 1
  notify-send -u normal "Starting awww... (★^O^★)"
fi

RES_W=1920
RES_H=1080
WORK_W=1200

IMAGES_NUM=6
NUM_PICS=$((RANDOM % IMAGES_NUM + 1))

# Search all subdirectories, but always skip spicy
FIND_OPTS=("-type" "d" "-name" "spicy" "-prune" "-o")

# Only static images
mapfile -d $'\0' SELECTED_PICS < <(find "$WALLPAPER_DIR" "${FIND_OPTS[@]}" -type f \( -iname "*.jpg" -o -iname "*.JPG" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.ico" \) -print0 | shuf -z -n "$NUM_PICS")

if [ ${#SELECTED_PICS[@]} -eq 0 ]; then
  notify-send -u critical "Cannot find images (*≧m≦*)"
  sleep 30
  exit 1
fi

RANDOM_TRANS=${TRANSITIONS[$RANDOM % ${#TRANSITIONS[@]}]}

# Collage
CMD=("magick" "-size" "${RES_W}x${RES_H}" "xc:${BG_COLOR}")
SEGMENT_WIDTH=$((WORK_W / NUM_PICS))
readarray -t SHUFFLED_POS < <(seq 0 $((NUM_PICS - 1)) | shuf)

for i in "${!SELECTED_PICS[@]}"; do
  IMG="${SELECTED_PICS[$i]}"
  ANG=$(get_normal 0 12)

  BASE_X=$((SHUFFLED_POS[i] * SEGMENT_WIDTH + SEGMENT_WIDTH / 2))
  REL_X=$((BASE_X - WORK_W / 2))
  SIGMA_X=$((SEGMENT_WIDTH * 2 / 3))

  JITTER_X=$(($(get_normal 0 $SIGMA_X) % (SEGMENT_WIDTH / 2)))
  OFFSET_X=$((REL_X + JITTER_X))

  MAX_Y=$((RES_H / 2 - 350))
  [ "$MAX_Y" -lt 50 ] && MAX_Y=50
  SIGMA_Y=$((MAX_Y / 3))
  OFFSET_Y=$(($(get_normal 0 $SIGMA_Y) % (MAX_Y * 2)))

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

awww img "$TEMP_COLLAGE" --resize fit --fill-color "$AWWW_BG" --transition-type "$RANDOM_TRANS" --transition-step 90
