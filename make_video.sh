#!/bin/bash

usage() {
  echo "Usage: $0 image(s) audio output.mp4 [bitrate] [--slideshow duration]"
  echo "  For a static image: $0 image.jpg audio.m4a output.mp4 [bitrate]"
  echo "  For a slideshow: $0 'img1.jpg,img2.jpg,img3.jpg' audio.m4a output.mp4 [bitrate] --slideshow 5"
}

STATIC_MODE=true
DURATION=0

# Parse arguments
if [[ "$*" == *"--slideshow"* ]]; then
  STATIC_MODE=false
  IFS=' ' read -r -a parts <<< "$*"
  for ((i=0; i<${#parts[@]}; i++)); do
    if [[ "${parts[$i]}" == "--slideshow" ]]; then
      DURATION="${parts[$((i+1))]}"
    fi
  done
  # Remove --slideshow and duration from input
  set -- ${parts[@]/--slideshow/}
  set -- ${@/$DURATION/}
fi

IMAGES="$1"
AUDIO="$2"
OUTPUT="$3"
BITRATE="${4:-128k}"

if [ "$STATIC_MODE" = true ]; then
  ffmpeg -loop 1 -i "$IMAGES" -i "$AUDIO" \
    -c:v libx264 -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2" \
    -c:a aac -b:a "$BITRATE" -shortest -pix_fmt yuv420p "$OUTPUT"
else
  # Split images into array
  IFS=',' read -r -a img_array <<< "$IMAGES"
  input_args=()
  filter_inputs=""
  idx=0
  for img in "${img_array[@]}"; do
    input_args+=(-loop 1 -t $DURATION -i "$img")
    filter_inputs+="[$idx:v]"
    idx=$((idx+1))
  done
  filter_inputs+="concat=n=${#img_array[@]}:v=1:a=0,format=yuv420p[v]"
  ffmpeg "${input_args[@]}" -i "$AUDIO" \
    -filter_complex "$filter_inputs" \
    -map "[v]" -map $(($idx)):a -shortest \
    -c:v libx264 -c:a aac -b:a "$BITRATE" -pix_fmt yuv420p "$OUTPUT"
fi
