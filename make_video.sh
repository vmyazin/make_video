#!/bin/bash

usage() {
  echo "Usage: $0 media(s) audio output.mp4 [bitrate] [--slideshow duration]"
  echo "  For a static image: $0 image.jpg audio.m4a output.mp4 [bitrate]"
  echo "  For a slideshow: $0 'img1.jpg,img2.jpg,img3.jpg' audio.m4a output.mp4 [bitrate] --slideshow 5"
  echo "  For mixed media: $0 'img1.jpg,video1.mp4,img2.jpg' audio.m4a output.mp4 [bitrate] --slideshow 5"
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

# Check if required arguments are provided
if [ $# -lt 3 ]; then
  usage
  exit 1
fi

MEDIA="$1"
AUDIO="$2"
OUTPUT="$3"
BITRATE="${4:-128k}"

# Function to check if file is a video
is_video() {
  local file="$1"
  local ext="${file##*.}"
  case "$ext" in
    mp4|avi|mov|mkv|wmv|flv|webm|m4v|3gp|ogv)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

if [ "$STATIC_MODE" = true ]; then
  # Single media file (image or video)
  if is_video "$MEDIA"; then
    ffmpeg -i "$MEDIA" -i "$AUDIO" \
      -c:v libx264 -c:a aac -b:a "$BITRATE" -shortest -pix_fmt yuv420p "$OUTPUT"
  else
    ffmpeg -loop 1 -i "$MEDIA" -i "$AUDIO" \
      -c:v libx264 -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2" \
      -c:a aac -b:a "$BITRATE" -shortest -pix_fmt yuv420p "$OUTPUT"
  fi
else
  # Split media into array
  IFS=',' read -r -a media_array <<< "$MEDIA"
  input_args=()
  filter_inputs=""
  idx=0
  
  for media in "${media_array[@]}"; do
    if is_video "$media"; then
      # For videos, trim to duration if specified, otherwise use full video
      if [ "$DURATION" -gt 0 ]; then
        input_args+=(-t $DURATION -i "$media")
      else
        input_args+=(-i "$media")
      fi
    else
      # For images, loop and set duration
      input_args+=(-loop 1 -t $DURATION -i "$media")
    fi
    filter_inputs+="[$idx:v]"
    idx=$((idx+1))
  done
  
  filter_inputs+="concat=n=${#media_array[@]}:v=1:a=0,format=yuv420p[v]"
  ffmpeg "${input_args[@]}" -i "$AUDIO" \
    -filter_complex "$filter_inputs" \
    -map "[v]" -map $(($idx)):a -shortest \
    -c:v libx264 -c:a aac -b:a "$BITRATE" -pix_fmt yuv420p "$OUTPUT"
fi
