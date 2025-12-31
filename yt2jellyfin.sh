#!/usr/bin/env bash
#
# yt2jellyfin - Download YouTube audio as MP3 with full metadata for Jellyfin
#
# Features:
#   - Downloads best quality audio and converts to MP3 (320kbps)
#   - Embeds metadata: title, artist, album art (cropped to square)
#   - Organizes files in Jellyfin-compatible structure: Artist/Album/Track.mp3
#   - Supports single videos, playlists, channels, and search queries
#   - Archive support to avoid re-downloading
#   - Configurable output directory
#
# Supported platforms: Linux (Ubuntu/Debian, Fedora, Arch) and macOS
#
# Usage:
#   yt2jellyfin <url|search_query> [options]
#
# Examples:
#   yt2jellyfin "https://youtube.com/watch?v=VIDEO_ID"
#   yt2jellyfin "https://youtube.com/playlist?list=PLAYLIST_ID"
#   yt2jellyfin "artist name - song title" --search
#   yt2jellyfin URL --flat  # Single folder, no artist/album structure
#

set -euo pipefail

# ══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION - Edit these to match your setup
# ══════════════════════════════════════════════════════════════════════════════

# Default output directory (your Jellyfin music library path)
DEFAULT_OUTPUT_DIR="${YT2JELLYFIN_OUTPUT:-$HOME/Music/YouTube}"

# Archive file to track downloaded videos (prevents re-downloading)
ARCHIVE_FILE="${YT2JELLYFIN_ARCHIVE:-$HOME/.yt2jellyfin_archive.txt}"

# Audio quality: 0 = best VBR (~320kbps), or specify bitrate like "320K"
AUDIO_QUALITY="0"

# ══════════════════════════════════════════════════════════════════════════════
# COLORS AND FORMATTING
# ══════════════════════════════════════════════════════════════════════════════

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Use printf for macOS compatibility (echo -e is not portable)
log_info()    { printf "${BLUE}[INFO]${NC} %s\n" "$*"; }
log_success() { printf "${GREEN}[SUCCESS]${NC} %s\n" "$*"; }
log_warn()    { printf "${YELLOW}[WARN]${NC} %s\n" "$*"; }
log_error()   { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }
log_step()    { printf "${MAGENTA}[STEP]${NC} %s\n" "$*"; }

# ══════════════════════════════════════════════════════════════════════════════
# HELP / USAGE
# ══════════════════════════════════════════════════════════════════════════════

show_help() {
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                           yt2jellyfin                                        ║
║            Download YouTube audio as MP3 for Jellyfin                        ║
╚══════════════════════════════════════════════════════════════════════════════╝

USAGE:
    yt2jellyfin <url|query> [OPTIONS]

ARGUMENTS:
    url         YouTube video URL, playlist URL, or channel URL
    query       Search query (use with --search flag)

OPTIONS:
    -o, --output DIR      Output directory (default: ~/Music/YouTube)
    -s, --search          Treat input as a search query
    -n, --number N        Number of search results to download (default: 1)
    -f, --flat            Flat structure (no Artist/Album folders)
    -a, --album NAME      Override album name
    -A, --artist NAME     Override artist name
    -p, --playlist-folder Use playlist name as album folder
    --no-archive          Don't track downloads (allow re-downloading)
    --no-thumbnail        Skip thumbnail embedding
    --keep-video          Keep intermediate video file
    -q, --quiet           Suppress yt-dlp output
    -v, --verbose         Show detailed output
    -h, --help            Show this help message
    --update              Update yt-dlp to latest version
    --check               Check dependencies

EXAMPLES:
    # Download a single video
    yt2jellyfin "https://youtube.com/watch?v=dQw4w9WgXcQ"

    # Download entire playlist, organized by playlist name
    yt2jellyfin "https://youtube.com/playlist?list=PLxyz" --playlist-folder

    # Search and download first result
    yt2jellyfin "never gonna give you up" --search

    # Search and download top 5 results
    yt2jellyfin "lofi hip hop" --search -n 5

    # Download to specific directory with flat structure
    yt2jellyfin URL -o /path/to/jellyfin/music -f

    # Override artist and album
    yt2jellyfin URL --artist "Rick Astley" --album "Greatest Hits"

ENVIRONMENT VARIABLES:
    YT2JELLYFIN_OUTPUT    Default output directory
    YT2JELLYFIN_ARCHIVE   Archive file location

JELLYFIN STRUCTURE:
    By default, files are organized as:
    Music/
    └── Artist Name/
        └── Album or Single/
            └── Track Title.mp3

    With --flat flag:
    Music/
    └── Track Title.mp3

EOF
}

# ══════════════════════════════════════════════════════════════════════════════
# PLATFORM DETECTION
# ══════════════════════════════════════════════════════════════════════════════

detect_platform() {
    case "$(uname -s)" in
        Darwin*)  echo "macos" ;;
        Linux*)   echo "linux" ;;
        *)        echo "unknown" ;;
    esac
}

# ══════════════════════════════════════════════════════════════════════════════
# DEPENDENCY CHECKS
# ══════════════════════════════════════════════════════════════════════════════

check_dependencies() {
    local missing=()
    local platform
    platform=$(detect_platform)

    log_step "Checking dependencies..."
    log_info "Platform: $platform"

    # Required
    if ! command -v yt-dlp &> /dev/null; then
        missing+=("yt-dlp")
    else
        log_success "yt-dlp $(yt-dlp --version)"
    fi

    if ! command -v ffmpeg &> /dev/null; then
        missing+=("ffmpeg")
    else
        log_success "ffmpeg found"
    fi

    if ! command -v ffprobe &> /dev/null; then
        missing+=("ffprobe (usually comes with ffmpeg)")
    else
        log_success "ffprobe found"
    fi

    # Optional but recommended
    if command -v mutagen-inspect &> /dev/null || python3 -c "import mutagen" 2>/dev/null; then
        log_success "mutagen found (better thumbnail embedding)"
    else
        log_warn "mutagen not found (optional - install with: pip3 install mutagen)"
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing required dependencies:"
        for dep in "${missing[@]}"; do
            printf "  - %s\n" "$dep"
        done
        printf "\n"

        if [ "$platform" = "macos" ]; then
            printf "Install on macOS (using Homebrew):\n"
            printf "  brew install ffmpeg yt-dlp\n"
            printf "  pip3 install mutagen\n"
            printf "\n"
            printf "If you don't have Homebrew installed:\n"
            printf "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"\n"
        else
            printf "Install on Ubuntu/Debian:\n"
            printf "  sudo apt update && sudo apt install ffmpeg\n"
            printf "  pip3 install yt-dlp mutagen\n"
            printf "\n"
            printf "Install on Fedora:\n"
            printf "  sudo dnf install ffmpeg\n"
            printf "  pip3 install yt-dlp mutagen\n"
            printf "\n"
            printf "Install on Arch Linux:\n"
            printf "  sudo pacman -S ffmpeg yt-dlp python-mutagen\n"
        fi
        printf "\n"
        printf "Or use pipx for isolated install:\n"
        printf "  pipx install yt-dlp\n"
        return 1
    fi

    log_success "All required dependencies found!"
    return 0
}

update_ytdlp() {
    local platform
    platform=$(detect_platform)

    log_step "Updating yt-dlp..."

    if [ "$platform" = "macos" ] && command -v brew &> /dev/null && brew list yt-dlp &> /dev/null; then
        brew upgrade yt-dlp || true
    elif command -v pipx &> /dev/null && pipx list | grep -q yt-dlp; then
        pipx upgrade yt-dlp
    elif pip3 show yt-dlp &> /dev/null 2>&1; then
        pip3 install --upgrade yt-dlp --break-system-packages 2>/dev/null || \
        pip3 install --upgrade yt-dlp --user 2>/dev/null || \
        pip3 install --upgrade yt-dlp
    else
        log_warn "yt-dlp not installed via brew/pip/pipx, trying yt-dlp self-update..."
        yt-dlp -U
    fi
    log_success "yt-dlp updated to $(yt-dlp --version)"
}

# ══════════════════════════════════════════════════════════════════════════════
# CORE DOWNLOAD FUNCTION
# ══════════════════════════════════════════════════════════════════════════════

download_audio() {
    local input="$1"
    local output_dir="$2"
    local is_search="${3:-false}"
    local search_count="${4:-1}"
    local flat_structure="${5:-false}"
    local use_playlist_folder="${6:-false}"
    local custom_artist="${7:-}"
    local custom_album="${8:-}"
    local use_archive="${9:-true}"
    local embed_thumbnail="${10:-true}"
    local keep_video="${11:-false}"
    local quiet="${12:-false}"
    local verbose="${13:-false}"

    # Build yt-dlp arguments
    local ytdlp_args=()

    # === AUDIO EXTRACTION ===
    ytdlp_args+=(
        --extract-audio
        --audio-format mp3
        --audio-quality "$AUDIO_QUALITY"
        -f "bestaudio/best"
    )

    # === METADATA ===
    ytdlp_args+=(
        --embed-metadata
        --add-metadata
        # Parse uploader/channel as artist if not in metadata
        --parse-metadata "%(uploader,channel)s:%(meta_artist)s"
        # Use playlist title as album for playlist downloads
        --parse-metadata "%(playlist_title,title)s:%(meta_album)s"
        # Track number from playlist index
        --parse-metadata "%(playlist_index)s:%(meta_track)s"
    )

    # === THUMBNAIL (ALBUM ART) ===
    if [ "$embed_thumbnail" = "true" ]; then
        ytdlp_args+=(
            --embed-thumbnail
            --convert-thumbnails png
            # Crop thumbnail to square (better for music players)
            --ppa "ThumbnailsConvertor+ffmpeg_o:-c:v png -vf crop=\"'if(gt(ih,iw),iw,ih)':'if(gt(iw,ih),ih,iw)'\""
        )
    fi

    # === OUTPUT TEMPLATE ===
    local output_template

    if [ "$flat_structure" = "true" ]; then
        # Flat: just filename in output dir
        output_template="${output_dir}/%(title)s.%(ext)s"
    elif [ "$use_playlist_folder" = "true" ]; then
        # Playlist mode: Artist/Playlist/## - Track.mp3
        output_template="${output_dir}/%(uploader,channel)s/%(playlist_title,album,title)s/%(playlist_index&{} - |)s%(title)s.%(ext)s"
    else
        # Default: Artist/Album/Track.mp3 (singles go to "Singles" album)
        output_template="${output_dir}/%(uploader,channel)s/%(album,playlist_title)s/%(title)s.%(ext)s"
    fi

    # Override artist in path if specified
    if [ -n "$custom_artist" ]; then
        output_template="${output_dir}/${custom_artist}/%(album,playlist_title,title)s/%(title)s.%(ext)s"
        ytdlp_args+=(--parse-metadata ":%(meta_artist)s:${custom_artist}")
    fi

    # Override album in path if specified
    if [ -n "$custom_album" ]; then
        if [ -n "$custom_artist" ]; then
            output_template="${output_dir}/${custom_artist}/${custom_album}/%(title)s.%(ext)s"
        else
            output_template="${output_dir}/%(uploader,channel)s/${custom_album}/%(title)s.%(ext)s"
        fi
        ytdlp_args+=(--parse-metadata ":%(meta_album)s:${custom_album}")
    fi

    ytdlp_args+=(-o "$output_template")

    # === ARCHIVE (AVOID RE-DOWNLOADING) ===
    if [ "$use_archive" = "true" ]; then
        ytdlp_args+=(--download-archive "$ARCHIVE_FILE")
    fi

    # === SEARCH MODE ===
    if [ "$is_search" = "true" ]; then
        input="ytsearch${search_count}:${input}"
    fi

    # === MISC OPTIONS ===
    ytdlp_args+=(
        --no-overwrites
        --continue
        --ignore-errors
        --no-warnings
        --restrict-filenames
        --windows-filenames
        # Concurrent fragments for faster download
        --concurrent-fragments 4
        # Retry on failure
        --retries 3
        --fragment-retries 3
    )

    if [ "$keep_video" = "true" ]; then
        ytdlp_args+=(--keep-video)
    fi

    if [ "$quiet" = "true" ]; then
        ytdlp_args+=(--quiet --no-progress)
    elif [ "$verbose" = "true" ]; then
        ytdlp_args+=(--verbose)
    else
        ytdlp_args+=(--progress --newline)
    fi

    # === EXECUTE ===
    log_step "Starting download..."
    log_info "Input: $input"
    log_info "Output: $output_dir"

    if [ "$verbose" = "true" ]; then
        log_info "yt-dlp arguments:"
        printf '  %s\n' "${ytdlp_args[@]}"
    fi

    printf "\n"

    if yt-dlp "${ytdlp_args[@]}" "$input"; then
        printf "\n"
        log_success "Download complete!"
        log_info "Files saved to: $output_dir"

        # Show what was downloaded (use -mmin for both Linux and macOS compatibility)
        if [ "$quiet" != "true" ]; then
            printf "\n"
            log_info "Recently modified files:"
            find "$output_dir" -name "*.mp3" -mmin -5 -type f 2>/dev/null | head -10 | while read -r file; do
                printf "  ${GREEN}✓${NC} %s\n" "$(basename "$file")"
            done
        fi
        return 0
    else
        log_error "Download failed or partially completed"
        return 1
    fi
}

# ══════════════════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════════════════

main() {
    # Default values
    local input=""
    local output_dir="$DEFAULT_OUTPUT_DIR"
    local is_search="false"
    local search_count="1"
    local flat_structure="false"
    local use_playlist_folder="false"
    local custom_artist=""
    local custom_album=""
    local use_archive="true"
    local embed_thumbnail="true"
    local keep_video="false"
    local quiet="false"
    local verbose="false"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            --check)
                check_dependencies
                exit $?
                ;;
            --update)
                update_ytdlp
                exit $?
                ;;
            -o|--output)
                output_dir="$2"
                shift 2
                ;;
            -s|--search)
                is_search="true"
                shift
                ;;
            -n|--number)
                search_count="$2"
                shift 2
                ;;
            -f|--flat)
                flat_structure="true"
                shift
                ;;
            -p|--playlist-folder)
                use_playlist_folder="true"
                shift
                ;;
            -a|--album)
                custom_album="$2"
                shift 2
                ;;
            -A|--artist)
                custom_artist="$2"
                shift 2
                ;;
            --no-archive)
                use_archive="false"
                shift
                ;;
            --no-thumbnail)
                embed_thumbnail="false"
                shift
                ;;
            --keep-video)
                keep_video="true"
                shift
                ;;
            -q|--quiet)
                quiet="true"
                shift
                ;;
            -v|--verbose)
                verbose="true"
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                printf "Use --help for usage information\n"
                exit 1
                ;;
            *)
                if [ -z "$input" ]; then
                    input="$1"
                else
                    log_error "Multiple inputs not supported. Use playlist URL instead."
                    exit 1
                fi
                shift
                ;;
        esac
    done

    # Validate input
    if [ -z "$input" ]; then
        log_error "No URL or search query provided"
        printf "\n"
        show_help
        exit 1
    fi

    # Check dependencies
    if ! command -v yt-dlp &> /dev/null || ! command -v ffmpeg &> /dev/null; then
        log_error "Missing dependencies. Run: $0 --check"
        exit 1
    fi

    # Create output directory
    mkdir -p "$output_dir"

    # Show banner
    if [ "$quiet" != "true" ]; then
        printf "\n"
        printf "${BOLD}${CYAN}██╗   ██╗████████╗██████╗      ██╗███████╗██╗     ██╗  ██╗   ██╗███████╗██╗███╗   ██╗${NC}\n"
        printf "${BOLD}${CYAN}╚██╗ ██╔╝╚══██╔══╝╚════██╗     ██║██╔════╝██║     ██║  ╚██╗ ██╔╝██╔════╝██║████╗  ██║${NC}\n"
        printf "${BOLD}${CYAN} ╚████╔╝    ██║    █████╔╝     ██║█████╗  ██║     ██║   ╚████╔╝ █████╗  ██║██╔██╗ ██║${NC}\n"
        printf "${BOLD}${CYAN}  ╚██╔╝     ██║   ██╔═══╝ ██   ██║██╔══╝  ██║     ██║    ╚██╔╝  ██╔══╝  ██║██║╚██╗██║${NC}\n"
        printf "${BOLD}${CYAN}   ██║      ██║   ███████╗╚█████╔╝███████╗███████╗███████╗██║   ██║     ██║██║ ╚████║${NC}\n"
        printf "${BOLD}${CYAN}   ╚═╝      ╚═╝   ╚══════╝ ╚════╝ ╚══════╝╚══════╝╚══════╝╚═╝   ╚═╝     ╚═╝╚═╝  ╚═══╝${NC}\n"
        printf "\n"
    fi

    # Execute download
    download_audio \
        "$input" \
        "$output_dir" \
        "$is_search" \
        "$search_count" \
        "$flat_structure" \
        "$use_playlist_folder" \
        "$custom_artist" \
        "$custom_album" \
        "$use_archive" \
        "$embed_thumbnail" \
        "$keep_video" \
        "$quiet" \
        "$verbose"
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
