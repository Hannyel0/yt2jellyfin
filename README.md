# yt2jellyfin

![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-blue)
![Shell](https://img.shields.io/badge/shell-bash-green)
![License](https://img.shields.io/badge/license-MIT-yellow)
[![yt-dlp](https://img.shields.io/badge/powered%20by-yt--dlp-red)](https://github.com/yt-dlp/yt-dlp)

Download YouTube audio as high-quality MP3 files, automatically organized for Jellyfin.

## Features

- Downloads best audio quality, converts to MP3 (320kbps)
- Embeds metadata and album art (cropped to square)
- Organizes files as `Artist/Album/Track.mp3`
- Supports videos, playlists, channels, and search queries
- Tracks downloads to prevent duplicates

## Installation

### Quick Install

```bash
chmod +x setup-yt2jellyfin.sh
./setup-yt2jellyfin.sh
```

### Manual Install

**macOS:**
```bash
brew install ffmpeg yt-dlp
pip3 install mutagen
cp yt2jellyfin.sh ~/.local/bin/yt2jellyfin
chmod +x ~/.local/bin/yt2jellyfin
```

**Linux:**
```bash
sudo apt install ffmpeg  # or dnf/pacman
pip3 install --user yt-dlp mutagen
cp yt2jellyfin.sh ~/.local/bin/yt2jellyfin
chmod +x ~/.local/bin/yt2jellyfin
```

Add `~/.local/bin` to your PATH if needed.

## Usage

```bash
# Download a video
yt2jellyfin "https://youtube.com/watch?v=VIDEO_ID"

# Download a playlist
yt2jellyfin "https://youtube.com/playlist?list=PLAYLIST_ID" --playlist-folder

# Search and download
yt2jellyfin "artist - song name" --search

# See all options
yt2jellyfin --help
```

### Options

| Option | Description |
|--------|-------------|
| `-o, --output DIR` | Output directory (default: `~/Music/YouTube`) |
| `-s, --search` | Treat input as search query |
| `-n, --number N` | Number of search results (default: 1) |
| `-f, --flat` | No Artist/Album folders |
| `-a, --album NAME` | Override album name |
| `-A, --artist NAME` | Override artist name |
| `-p, --playlist-folder` | Use playlist name as folder |
| `--no-archive` | Allow re-downloading |
| `--check` | Check dependencies |
| `--update` | Update yt-dlp |

## Configuration

Set environment variables in `~/.zshrc` or `~/.bashrc`:

```bash
export YT2JELLYFIN_OUTPUT="/path/to/jellyfin/music"
```

## License

MIT License - Use freely for personal purposes. Respect YouTube's Terms of Service.
