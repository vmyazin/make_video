#!/bin/bash
# process_chunks.sh

echo "Processing audio chunks with video loops..."

# Create output directory for video chunks
mkdir -p temp_video_chunks

# Process each audio chunk
for chunk in temp_chunks/audio_chunk_*.m4a; do
    if [ -f "$chunk" ]; then
        chunk_name=$(basename "$chunk" .m4a)
        output_file="temp_video_chunks/${chunk_name}_video.mp4"
        
        echo "Processing $chunk -> $output_file"
        
        ./make_video.sh "my_videos/Jazzy Mantra Mix/Cat Dance.mp4,my_videos/Jazzy Mantra Mix/Cat Dance 2.mp4" "$chunk" "$output_file" 192k --loop
        
        if [ $? -eq 0 ]; then
            echo "✅ Successfully processed $chunk_name"
        else
            echo "❌ Failed to process $chunk_name"
            exit 1
        fi
    fi
done

echo "All chunks processed successfully!"
