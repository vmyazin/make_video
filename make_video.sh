#!/bin/bash
# make_video.sh

usage() {
  echo "Usage: $0 media(s) audio output.mp4 [bitrate] [--slideshow duration] [--loop]"
  echo "  For a static image: $0 image.jpg audio.m4a output.mp4 [bitrate]"
  echo "  For a slideshow: $0 'img1.jpg,img2.jpg,img3.jpg' audio.m4a output.mp4 [bitrate] --slideshow 5"
  echo "  For mixed media: $0 'img1.jpg,video1.mp4,img2.jpg' audio.m4a output.mp4 [bitrate] --slideshow 5"
  echo "  For looping videos: $0 'video1.mp4,video2.mp4' audio.m4a output.mp4 [bitrate] --loop"
  echo "  For looping slideshow: $0 'img1.jpg,img2.jpg' audio.m4a output.mp4 [bitrate] --slideshow 3 --loop"
  echo "  With wildcards: $0 'my_videos/*.mp4' audio.m4a output.mp4 [bitrate] --loop"
  echo "  Mixed wildcards: $0 'images/*.jpg,videos/*.mp4' audio.m4a output.mp4 [bitrate] --slideshow 5"
  echo "  Force chunked processing: add --chunk [--chunk-seconds N]"
  echo "    - The script also auto-chunks long jobs to avoid OOM and create robust outputs"
}

STATIC_MODE=true
DURATION=0
LOOP_MODE=false
CHUNK_MODE=false
CHUNK_SECONDS=300
# honor env to disable auto-chunk in nested calls
DISABLE_AUTO_CHUNK=${MAKE_VIDEO_DISABLE_AUTO_CHUNK:-0}
# Internal safety threshold: if the number of concat segments would exceed this,
# switch to chunked processing automatically to reduce memory/FD pressure.
AUTO_CHUNK_SEGMENTS_THRESHOLD=80

# Parse flags without mutating filenames
args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --slideshow)
      STATIC_MODE=false
      if [[ -n "$2" && "$2" != --* ]]; then
        DURATION="$2"
        shift 2
        continue
      else
        echo "Error: --slideshow requires a duration (seconds)"
        usage
        exit 1
      fi
      ;;
    --loop)
      LOOP_MODE=true
      shift
      ;;
    --chunk)
      CHUNK_MODE=true
      shift
      ;;
    --chunk-seconds)
      if [[ -n "$2" && "$2" != --* ]]; then
        CHUNK_SECONDS="$2"
        CHUNK_MODE=true
        shift 2
        continue
      else
        echo "Error: --chunk-seconds requires a duration (seconds)"
        usage
        exit 1
      fi
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done

# Reset positional parameters to non-flag args
set -- "${args[@]}"

# Check if required arguments are provided
if [ $# -lt 3 ]; then
  usage
  exit 1
fi

MEDIA="$1"
AUDIO="$2"
OUTPUT="$3"
BITRATE="${4:-128k}"

# Auto-switch to slideshow-style processing when needed
# - Wildcards (e.g., *.mp4) or comma-separated media imply multiple inputs
# - Loop mode should also use the multi-input/slideshow pipeline
if [[ "$MEDIA" == *"*"* || "$MEDIA" == *","* ]]; then
  STATIC_MODE=false
fi
if [ "$LOOP_MODE" = true ]; then
  STATIC_MODE=false
fi

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

# Function to expand wildcards in media string
expand_wildcards() {
  local media_string="$1"
  local expanded_files=()
  
  # Split by comma and process each part
  IFS=',' read -r -a parts <<< "$media_string"
  
  for part in "${parts[@]}"; do
    # Trim whitespace
    part=$(echo "$part" | xargs)
    
    if [[ "$part" == *"*"* ]]; then
      # Contains wildcard, expand it
      for file in $part; do
        if [ -f "$file" ]; then
          expanded_files+=("$file")
        fi
      done
    else
      # No wildcard, add as-is
      if [ -f "$part" ]; then
        expanded_files+=("$part")
      fi
    fi
  done
  
  # Join with commas
  printf '%s\n' "${expanded_files[@]}" | tr '\n' ',' | sed 's/,$//'
}

# Function to get media duration in seconds (float)
get_duration_seconds() {
  local file="$1"
  ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null | awk '{ if ($1=="N/A" || $1=="") print 0; else print $1 }'
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
  # Expand wildcards and split media into array
  expanded_media=$(expand_wildcards "$MEDIA")
  if [ -z "$expanded_media" ]; then
    echo "Error: No matching files found for: $MEDIA"
    exit 1
  fi
  IFS=',' read -r -a media_array <<< "$expanded_media"
  
  if [ "$LOOP_MODE" = true ]; then
    # Loop mode: repeat the sequence enough times to cover the audio duration
    audio_duration=$(get_duration_seconds "$AUDIO")
    if [[ -z "$audio_duration" || "$audio_duration" == "0" ]]; then
      echo "Error: Could not determine audio duration for $AUDIO"
      exit 1
    fi

    # Build one pass to compute total sequence duration
    sequence_duration=0
    temp_inputs=()
    for media in "${media_array[@]}"; do
      if is_video "$media"; then
        dur=$(get_duration_seconds "$media")
        temp_inputs+=("$media:$dur:video")
      else
        img_duration="${DURATION:-5}"
        temp_inputs+=("$media:$img_duration:image")
      fi
    done

    # Sum durations for a single cycle
    for entry in "${temp_inputs[@]}"; do
      IFS=':' read -r file dur kind <<< "$entry"
      sequence_duration=$(awk -v a="$sequence_duration" -v b="$dur" 'BEGIN{printf "%.6f", a+b}')
    done

    if [[ "$sequence_duration" == "0" || -z "$sequence_duration" ]]; then
      echo "Error: Computed zero sequence duration"
      exit 1
    fi

    # Determine repeat count (ceil)
    repeat_count=$(awk -v a="$audio_duration" -v b="$sequence_duration" 'BEGIN{printf "%d", (a/b==int(a/b)?a/b:int(a/b)+1)}')
    if [ "$repeat_count" -lt 1 ]; then
      repeat_count=1
    fi

    # If too many segments or explicit chunking requested, switch to chunked processing
    total_segments=$(( ${#temp_inputs[@]} * repeat_count ))
    if [ "$CHUNK_MODE" = true ] || { [ "$DISABLE_AUTO_CHUNK" != "1" ] && [ "$total_segments" -gt "$AUTO_CHUNK_SEGMENTS_THRESHOLD" ]; }; then
      # Create temp workspace
      TEMP_ROOT=$(mktemp -d 2>/dev/null || mktemp -d -t 'makevideo')
      CHUNK_DIR="$TEMP_ROOT/audio"
      VIDEO_DIR="$TEMP_ROOT/video"
      mkdir -p "$CHUNK_DIR" "$VIDEO_DIR"

      # 1) Segment the audio without re-encoding
      ffmpeg -y -i "$AUDIO" -f segment -segment_time "$CHUNK_SECONDS" -c copy "$CHUNK_DIR/chunk_%03d.m4a"
      if [ $? -ne 0 ]; then
        echo "Error: audio chunking failed"
        rm -rf "$TEMP_ROOT"
        exit 1
      fi

      shopt -s nullglob
      chunks=("$CHUNK_DIR"/chunk_*.m4a)
      shopt -u nullglob
      if [ ${#chunks[@]} -eq 0 ]; then
        echo "Error: no audio chunks produced"
        rm -rf "$TEMP_ROOT"
        exit 1
      fi

      # 2) Process each chunk by looping the media sequence to cover that chunk
      idxc=0
      for chunk_file in "${chunks[@]}"; do
        base=$(basename "$chunk_file" .m4a)
        out_chunk="$VIDEO_DIR/${base}_video.mp4"
        # Disable auto-chunk for nested call to avoid recursion
        MAKE_VIDEO_DISABLE_AUTO_CHUNK=1 "$0" "$MEDIA" "$chunk_file" "$out_chunk" "$BITRATE" --loop
        if [ $? -ne 0 ]; then
          echo "Error: failed processing chunk $chunk_file"
          rm -rf "$TEMP_ROOT"
          exit 1
        fi
        idxc=$((idxc+1))
      done

      # 3) Build concat list and concatenate losslessly
      LIST_FILE="$TEMP_ROOT/list.txt"
      : > "$LIST_FILE"
      for vf in "$VIDEO_DIR"/*_video.mp4; do
        # Paths have no single quotes; still quote defensively
        printf "file '%s'\n" "$vf" >> "$LIST_FILE"
      done
      ffmpeg -y -f concat -safe 0 -i "$LIST_FILE" -c copy "$OUTPUT"
      status=$?
      rm -rf "$TEMP_ROOT"
      if [ $status -ne 0 ]; then
        echo "Error: concatenation failed"
        exit 1
      fi
      exit 0
    fi

    # Build ffmpeg inputs and concat filter for repeated sequences
    input_args=()
    filter_inputs=""
    idx=0
    for ((r=0; r<repeat_count; r++)); do
      for entry in "${temp_inputs[@]}"; do
        IFS=':' read -r file dur kind <<< "$entry"
        if [ "$kind" = "video" ]; then
          input_args+=(-i "$file")
        else
          input_args+=(-loop 1 -t $dur -i "$file")
        fi
        filter_inputs+="[$idx:v]"
        idx=$((idx+1))
      done
    done

    num_segments=$(( ${#temp_inputs[@]} * repeat_count ))
    filter_inputs+="concat=n=$num_segments:v=1:a=0,format=yuv420p[v]"

    ffmpeg "${input_args[@]}" -i "$AUDIO" \
      -filter_complex "$filter_inputs" \
      -map "[v]" -map $(($idx)):a -shortest \
      -c:v libx264 -c:a aac -b:a "$BITRATE" -pix_fmt yuv420p "$OUTPUT"
  else
    # Regular slideshow mode
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
fi
