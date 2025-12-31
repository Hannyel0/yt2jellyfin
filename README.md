# yt2jellyfin

A command-line tool for downloading YouTube audio as high-quality MP3 files, automatically organized in a Jellyfin-compatible folder structure.

**Supported Platforms:** macOS and Linux (Ubuntu/Debian, Fedora, Arch)

## Features

- **High-Quality Audio**: Downloads best available audio and converts to MP3 (320kbps VBR)
- **Automatic Metadata**: Embeds title, artist, album, and track number
- **Album Art**: Embeds thumbnails cropped to square format for optimal display in music players
- **Jellyfin-Compatible Structure**: Organizes files as `Artist/Album/Track.mp3`
- **Flexible Input**: Supports single videos, playlists, channels, and search queries
- **Download Archive**: Tracks downloaded videos to prevent duplicates
- **Customizable**: Override artist/album names, use flat structure, or organize by playlist
- **Cross-Platform**: Works on macOS and Linux

## Requirements

- **yt-dlp** - YouTube downloader
- **ffmpeg** - Audio conversion and thumbnail processing
- **Python 3** - Required by yt-dlp
- **mutagen** (optional) - Better thumbnail embedding

## Installation

### Quick Install

Run the setup script to install all dependencies and configure the tool:

```bash
chmod +x setup-yt2jellyfin.sh
./setup-yt2jellyfin.sh
```

The setup script will:
1. Detect your platform (macOS or Linux)
2. Install system dependencies (ffmpeg, python3) via Homebrew (macOS) or apt/dnf/pacman (Linux)
3. Install yt-dlp and mutagen
4. Install `yt2jellyfin` to `~/.local/bin`
5. Configure your default output directory
6. Create a yt-dlp configuration file

### Manual Installation

#### macOS (using Homebrew)

```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install dependencies
brew install ffmpeg yt-dlp
pip3 install mutagen

# Install the script
cp yt2jellyfin.sh ~/.local/bin/yt2jellyfin
chmod +x ~/.local/bin/yt2jellyfin

# Add to PATH (add to ~/.zshrc or ~/.bash_profile)
export PATH="$HOME/.local/bin:$PATH"
```

#### Linux

```bash
# Ubuntu/Debian
sudo apt update && sudo apt install -y ffmpeg python3 python3-pip
pip3 install --user yt-dlp mutagen

# Fedora
sudo dnf install -y ffmpeg python3 python3-pip
pip3 install --user yt-dlp mutagen

# Arch Linux
sudo pacman -S ffmpeg yt-dlp python-mutagen

# Install the script
mkdir -p ~/.local/bin
cp yt2jellyfin.sh ~/.local/bin/yt2jellyfin
chmod +x ~/.local/bin/yt2jellyfin

# Add to PATH (add to ~/.bashrc or ~/.zshrc)
export PATH="$HOME/.local/bin:$PATH"
```

## Usage

### Basic Examples

```bash
# Download a single video
yt2jellyfin "https://youtube.com/watch?v=VIDEO_ID"

# Download an entire playlist, organized by playlist name
yt2jellyfin "https://youtube.com/playlist?list=PLAYLIST_ID" --playlist-folder

# Search and download the first result
yt2jellyfin "never gonna give you up" --search

# Search and download top 5 results
yt2jellyfin "lofi hip hop" --search -n 5

# Download to a specific directory with flat structure
yt2jellyfin "https://youtube.com/watch?v=VIDEO_ID" -o /path/to/music -f

# Override artist and album metadata
yt2jellyfin "https://youtube.com/watch?v=VIDEO_ID" --artist "Rick Astley" --album "Greatest Hits"
```

### Command Options

| Option | Description |
|--------|-------------|
| `-o, --output DIR` | Output directory (default: `~/Music/YouTube`) |
| `-s, --search` | Treat input as a search query |
| `-n, --number N` | Number of search results to download (default: 1) |
| `-f, --flat` | Flat structure (no Artist/Album folders) |
| `-a, --album NAME` | Override album name |
| `-A, --artist NAME` | Override artist name |
| `-p, --playlist-folder` | Use playlist name as album folder |
| `--no-archive` | Don't track downloads (allow re-downloading) |
| `--no-thumbnail` | Skip thumbnail embedding |
| `--keep-video` | Keep intermediate video file |
| `-q, --quiet` | Suppress yt-dlp output |
| `-v, --verbose` | Show detailed output |
| `-h, --help` | Show help message |
| `--update` | Update yt-dlp to latest version |
| `--check` | Check dependencies |

## Output Structure

### Default Structure
```
Music/
└── Artist Name/
    └── Album or Single/
        └── Track Title.mp3
```

### With `--playlist-folder`
```
Music/
└── Channel Name/
    └── Playlist Name/
        ├── 01 - First Track.mp3
        ├── 02 - Second Track.mp3
        └── 03 - Third Track.mp3
```

### With `--flat`
```
Music/
├── Track One.mp3
├── Track Two.mp3
└── Track Three.mp3
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `YT2JELLYFIN_OUTPUT` | Default output directory | `~/Music/YouTube` |
| `YT2JELLYFIN_ARCHIVE` | Archive file location | `~/.yt2jellyfin_archive.txt` |

Set these in your shell configuration file:

**macOS (zsh)** - Add to `~/.zshrc`:
```bash
export YT2JELLYFIN_OUTPUT="/path/to/jellyfin/music"
export YT2JELLYFIN_ARCHIVE="$HOME/.config/yt2jellyfin/archive.txt"
```

**Linux (bash)** - Add to `~/.bashrc`:
```bash
export YT2JELLYFIN_OUTPUT="/path/to/jellyfin/music"
export YT2JELLYFIN_ARCHIVE="$HOME/.config/yt2jellyfin/archive.txt"
```

### yt-dlp Configuration

The setup script creates a config file at `~/.config/yt-dlp/config`. You can customize it for additional options like:

- Browser cookies for age-restricted content (supports Safari on macOS)
- SponsorBlock integration
- Rate limiting
- Proxy settings

## Jellyfin Integration

For Jellyfin to properly detect your music:

1. Set your output directory to a path within your Jellyfin music library
2. Use the default folder structure (Artist/Album/Track.mp3)
3. After downloading, trigger a library scan in Jellyfin

The embedded metadata and album art will be automatically detected by Jellyfin.

## Troubleshooting

### Check Dependencies
```bash
yt2jellyfin --check
```

### Update yt-dlp
YouTube frequently changes its APIs. Keep yt-dlp updated:
```bash
yt2jellyfin --update

# Or manually:
# macOS (Homebrew)
brew upgrade yt-dlp

# Linux (pip)
pip3 install --upgrade yt-dlp
```

### Common Issues

**"Video unavailable" errors**: Some videos are region-locked or require authentication. Try using cookies:
```bash
# Add to ~/.config/yt-dlp/config
--cookies-from-browser safari    # macOS
--cookies-from-browser firefox   # Any platform
--cookies-from-browser chrome    # Any platform
```

**Download speed is slow**: yt-dlp uses concurrent fragment downloading by default (4 fragments). You can increase this in the config.

**Thumbnail not square**: The script automatically crops thumbnails to square. If you see issues, ensure ffmpeg is properly installed.

**Command not found after installation**: Make sure `~/.local/bin` is in your PATH:
```bash
# Check your PATH
echo $PATH

# If ~/.local/bin is missing, add it:
# For zsh (macOS default):
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# For bash:
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

## License

This project is provided as-is for personal use. Please respect YouTube's Terms of Service and copyright laws when using this tool.

## Contributing

Contributions are welcome! Feel free to submit issues and pull requests.

## Acknowledgments

- [yt-dlp](https://github.com/yt-dlp/yt-dlp) - The powerful YouTube downloader this tool is built upon
- [FFmpeg](https://ffmpeg.org/) - Audio/video processing
- [Jellyfin](https://jellyfin.org/) - The free software media system
- [Homebrew](https://brew.sh/) - Package manager for macOS
