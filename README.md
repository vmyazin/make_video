# Make Video Script

A simple bash script that transforms audio-only content into YouTube-ready videos by adding visual elements. Perfect for converting podcasts, interviews, music, or any audio content into uploadable video format using FFmpeg.

![Make Video Illustration](assets/make_video_image.jpg)

## Features

- 🎥 **YouTube-Ready Videos**: Transform any audio content into uploadable video format
- 🎙️ **Podcast & Interview Support**: Convert audio-only content to video for YouTube uploads
- 🖼️ **Static Image Videos**: Create videos from a single image with background audio
- 🎬 **Slideshow Videos**: Create slideshow videos from multiple images with custom duration per slide
- 🎵 **Audio Support**: Works with various audio formats (MP3, M4A, WAV, etc.)
- ⚙️ **Customizable Bitrate**: Control audio quality with custom bitrate settings
- 🚀 **Simple CLI**: Easy-to-use command-line interface

## Prerequisites

- **FFmpeg**: This script requires FFmpeg to be installed on your system
  - macOS: `brew install ffmpeg`
  - Ubuntu/Debian: `sudo apt update && sudo apt install ffmpeg`
  - Windows: Download from [ffmpeg.org](https://ffmpeg.org/download.html)

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/make_video.git
   cd make_video
   ```

2. Make the script executable:
   ```bash
   chmod +x make_video.sh
   ```

## Usage

### Static Image Video

Create a video from a single image with background audio:

```bash
./make_video.sh image.jpg audio.m4a output.mp4 [bitrate]
```

**Example:**
```bash
./make_video.sh photo.jpg background_music.mp3 my_video.mp4 192k
```

### Slideshow Video

Create a slideshow video from multiple images:

```bash
./make_video.sh 'img1.jpg,img2.jpg,img3.jpg' audio.m4a output.mp4 [bitrate] --slideshow 5
```

**Example:**
```bash
./make_video.sh 'slide1.jpg,slide2.jpg,slide3.jpg' presentation_audio.wav slideshow.mp4 256k --slideshow 3
```

### Parameters

- `image(s)`: Single image file or comma-separated list of images for slideshow
- `audio`: Audio file to use as background music
- `output.mp4`: Name of the output video file
- `bitrate` (optional): Audio bitrate (default: 128k)
- `--slideshow duration`: Duration in seconds for each slide (slideshow mode only)

## Examples

### Convert a podcast to YouTube video
```bash
./make_video.sh podcast_cover.jpg episode_audio.mp3 podcast_video.mp4 192k
```

### Create an interview video with slideshow
```bash
./make_video.sh 'interview_cover.jpg,guest_photo.jpg,company_logo.png' interview_audio.wav interview_video.mp4 256k --slideshow 10
```

### Convert music to YouTube video
```bash
./make_video.sh album_art.jpg song.mp3 music_video.mp4
```

### Create a presentation video
```bash
./make_video.sh 'slide1.png,slide2.png,slide3.png' voiceover.wav presentation.mp4 128k --slideshow 8
```

## Supported Formats

### Image Formats
- JPEG (.jpg, .jpeg)
- PNG (.png)
- BMP (.bmp)
- TIFF (.tiff)
- And other formats supported by FFmpeg

### Audio Formats
- MP3 (.mp3)
- M4A (.m4a)
- WAV (.wav)
- AAC (.aac)
- OGG (.ogg)
- And other formats supported by FFmpeg

### Output Format
- MP4 (.mp4) with H.264 video codec and AAC audio codec

## Technical Details

The script uses FFmpeg with the following configurations:
- **Video Codec**: H.264 (libx264)
- **Audio Codec**: AAC
- **Pixel Format**: YUV420P (for maximum compatibility)
- **Video Filter**: Automatic padding to ensure even dimensions
- **Duration**: Automatically matches the shortest input (audio or video)

## Troubleshooting

### Common Issues

1. **"ffmpeg: command not found"**
   - Install FFmpeg using the instructions in the Prerequisites section

2. **"Permission denied"**
   - Make sure the script is executable: `chmod +x make_video.sh`

3. **"No such file or directory"**
   - Check that all input files exist and paths are correct
   - Use absolute paths if needed

4. **Video quality issues**
   - Try increasing the bitrate (e.g., 256k, 320k)
   - Ensure input images are high quality

### Getting Help

If you encounter issues:
1. Check that FFmpeg is properly installed: `ffmpeg -version`
2. Verify all input files exist and are accessible
3. Try with different file formats
4. Check the FFmpeg documentation for advanced options

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

## License

This project is open source and available under the [MIT License](LICENSE).

## Use Cases

- **Podcasters**: Convert audio episodes to YouTube videos with cover art
- **Musicians**: Create music videos from album artwork and audio tracks
- **Interviewers**: Transform audio interviews into engaging video content
- **Content Creators**: Make any audio content YouTube-ready with visual elements
- **Educators**: Convert audio lectures or presentations to video format

## Acknowledgments

- Built with [FFmpeg](https://ffmpeg.org/) - the powerful multimedia framework
- Inspired by the need to make audio content YouTube-compatible

---

**Transform your audio into YouTube-ready videos!** 🎬✨
