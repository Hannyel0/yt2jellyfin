#!/usr/bin/env bash
#
# setup-yt2jellyfin.sh - Install and configure yt2jellyfin
#
# Supported platforms: Linux (Ubuntu/Debian, Fedora, Arch) and macOS
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Use printf for macOS compatibility (echo -e is not portable)
log_info()    { printf "${BLUE}[INFO]${NC} %s\n" "$*"; }
log_success() { printf "${GREEN}[SUCCESS]${NC} %s\n" "$*"; }
log_warn()    { printf "${YELLOW}[WARN]${NC} %s\n" "$*"; }
log_error()   { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }

printf "\n"
printf "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}\n"
printf "${GREEN}║${NC}            yt2jellyfin Setup Script                          ${GREEN}║${NC}\n"
printf "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
printf "\n"

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

PLATFORM=$(detect_platform)
log_info "Detected platform: $PLATFORM"

# ══════════════════════════════════════════════════════════════════════════════
# STEP 1: Install system dependencies
# ══════════════════════════════════════════════════════════════════════════════

log_info "Step 1: Installing system dependencies..."

if [ "$PLATFORM" = "macos" ]; then
    # macOS - use Homebrew
    if ! command -v brew &> /dev/null; then
        log_warn "Homebrew not found. Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add Homebrew to PATH for Apple Silicon Macs
        if [ -f "/opt/homebrew/bin/brew" ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    fi

    log_info "Installing ffmpeg via Homebrew..."
    brew install ffmpeg || brew upgrade ffmpeg || true

    # Ensure Python 3 is available
    if ! command -v python3 &> /dev/null; then
        log_info "Installing Python 3 via Homebrew..."
        brew install python3
    fi
elif command -v apt &> /dev/null; then
    # Debian/Ubuntu
    sudo apt update
    sudo apt install -y ffmpeg python3 python3-pip python3-venv
elif command -v dnf &> /dev/null; then
    # Fedora
    sudo dnf install -y ffmpeg python3 python3-pip
elif command -v pacman &> /dev/null; then
    # Arch Linux
    sudo pacman -S --noconfirm ffmpeg python python-pip
else
    log_warn "Unknown package manager. Please install ffmpeg and python3 manually."
fi

log_success "System dependencies installed"

# ══════════════════════════════════════════════════════════════════════════════
# STEP 2: Install yt-dlp and mutagen
# ══════════════════════════════════════════════════════════════════════════════

log_info "Step 2: Installing yt-dlp and mutagen..."

if [ "$PLATFORM" = "macos" ]; then
    # On macOS, prefer Homebrew for yt-dlp
    if command -v brew &> /dev/null; then
        brew install yt-dlp || brew upgrade yt-dlp || true
        # Install mutagen via pip
        pip3 install --user mutagen 2>/dev/null || \
        pip3 install mutagen --break-system-packages 2>/dev/null || \
        pip3 install mutagen || true
    else
        # Fallback to pip
        pip3 install --user yt-dlp mutagen 2>/dev/null || \
        pip3 install yt-dlp mutagen --break-system-packages 2>/dev/null || \
        pip3 install yt-dlp mutagen
    fi
else
    # Linux - try pipx first (cleaner), fall back to pip
    if command -v pipx &> /dev/null; then
        pipx install yt-dlp || pipx upgrade yt-dlp
        pipx inject yt-dlp mutagen || true
    else
        # Use pip with --break-system-packages for newer systems
        pip3 install --user --upgrade yt-dlp mutagen --break-system-packages 2>/dev/null || \
        pip3 install --user --upgrade yt-dlp mutagen || \
        pip install --user --upgrade yt-dlp mutagen
    fi
fi

# Verify yt-dlp installation
if command -v yt-dlp &> /dev/null; then
    log_success "yt-dlp $(yt-dlp --version) installed"
else
    log_error "yt-dlp installation failed. Please install manually."
    exit 1
fi

# ══════════════════════════════════════════════════════════════════════════════
# STEP 3: Install the script
# ══════════════════════════════════════════════════════════════════════════════

log_info "Step 3: Installing yt2jellyfin script..."

SCRIPT_SOURCE="$(dirname "$0")/yt2jellyfin.sh"
INSTALL_DIR="$HOME/.local/bin"

mkdir -p "$INSTALL_DIR"

if [ -f "$SCRIPT_SOURCE" ]; then
    cp "$SCRIPT_SOURCE" "$INSTALL_DIR/yt2jellyfin"
    chmod +x "$INSTALL_DIR/yt2jellyfin"
    log_success "Script installed to $INSTALL_DIR/yt2jellyfin"
else
    log_error "yt2jellyfin.sh not found in current directory"
    exit 1
fi

# Add to PATH if not already there
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    log_info "Adding $INSTALL_DIR to PATH..."

    # Detect shell configuration file
    SHELL_RC=""
    if [ -n "${ZSH_VERSION:-}" ] || [ -f "$HOME/.zshrc" ]; then
        SHELL_RC="$HOME/.zshrc"
    elif [ -f "$HOME/.bashrc" ]; then
        SHELL_RC="$HOME/.bashrc"
    elif [ -f "$HOME/.bash_profile" ]; then
        # macOS often uses .bash_profile instead of .bashrc
        SHELL_RC="$HOME/.bash_profile"
    fi

    if [ -n "$SHELL_RC" ]; then
        # Check if already added
        if ! grep -q 'yt2jellyfin' "$SHELL_RC" 2>/dev/null; then
            printf "\n" >> "$SHELL_RC"
            printf "# yt2jellyfin\n" >> "$SHELL_RC"
            printf 'export PATH="$HOME/.local/bin:$PATH"\n' >> "$SHELL_RC"
            log_info "Added PATH to $SHELL_RC"
        fi
        log_warn "Run 'source $SHELL_RC' or restart your terminal"
    fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# STEP 4: Configure defaults (optional)
# ══════════════════════════════════════════════════════════════════════════════

log_info "Step 4: Configuration..."

printf "\n"

# Default music path differs between macOS and Linux
if [ "$PLATFORM" = "macos" ]; then
    DEFAULT_MUSIC_PATH="$HOME/Music/YouTube"
else
    DEFAULT_MUSIC_PATH="$HOME/Music/YouTube"
fi

printf "Enter your Jellyfin music library path (or press Enter for %s): " "$DEFAULT_MUSIC_PATH"
read -r MUSIC_PATH
MUSIC_PATH="${MUSIC_PATH:-$DEFAULT_MUSIC_PATH}"

# Create the directory
mkdir -p "$MUSIC_PATH"

# Add environment variable
SHELL_RC="${SHELL_RC:-$HOME/.bashrc}"
if [ "$PLATFORM" = "macos" ] && [ -z "${SHELL_RC:-}" ]; then
    SHELL_RC="$HOME/.zshrc"
fi

if ! grep -q "YT2JELLYFIN_OUTPUT" "$SHELL_RC" 2>/dev/null; then
    printf "\n" >> "$SHELL_RC"
    printf "# yt2jellyfin default output directory\n" >> "$SHELL_RC"
    printf 'export YT2JELLYFIN_OUTPUT="%s"\n' "$MUSIC_PATH" >> "$SHELL_RC"
fi

log_success "Default output: $MUSIC_PATH"

# ══════════════════════════════════════════════════════════════════════════════
# STEP 5: Create yt-dlp config for extra customization
# ══════════════════════════════════════════════════════════════════════════════

log_info "Step 5: Creating yt-dlp config..."

YT_DLP_CONFIG="$HOME/.config/yt-dlp/config"
mkdir -p "$(dirname "$YT_DLP_CONFIG")"

if [ ! -f "$YT_DLP_CONFIG" ]; then
    cat > "$YT_DLP_CONFIG" << 'EOF'
# yt-dlp configuration
# This file is used by both yt-dlp directly and the yt2jellyfin script

# Prefer best quality
--format bestaudio/best

# Retry on errors
--retries 3
--fragment-retries 3

# Continue partial downloads
--continue

# Don't overwrite existing files
--no-overwrites

# Limit concurrent connections (be nice to servers)
--concurrent-fragments 4

# Add sponsorblock markers (optional - remove if you don't want this)
# --sponsorblock-mark all

# Cookies from browser (uncomment if you need to access age-restricted content)
# --cookies-from-browser firefox
# --cookies-from-browser chrome
# --cookies-from-browser safari
EOF
    log_success "Created yt-dlp config at $YT_DLP_CONFIG"
else
    log_info "yt-dlp config already exists at $YT_DLP_CONFIG"
fi

# ══════════════════════════════════════════════════════════════════════════════
# DONE
# ══════════════════════════════════════════════════════════════════════════════

printf "\n"
printf "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}\n"
printf "${GREEN}║${NC}                  Setup Complete!                             ${GREEN}║${NC}\n"
printf "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
printf "\n"
printf "Usage examples:\n"
printf "\n"
printf "  ${BLUE}# Download a video${NC}\n"
printf "  yt2jellyfin \"https://youtube.com/watch?v=VIDEO_ID\"\n"
printf "\n"
printf "  ${BLUE}# Download a playlist${NC}\n"
printf "  yt2jellyfin \"https://youtube.com/playlist?list=PLAYLIST_ID\" --playlist-folder\n"
printf "\n"
printf "  ${BLUE}# Search and download${NC}\n"
printf "  yt2jellyfin \"artist - song name\" --search\n"
printf "\n"
printf "  ${BLUE}# See all options${NC}\n"
printf "  yt2jellyfin --help\n"
printf "\n"
printf "${YELLOW}Note: Restart your terminal or run 'source %s' to use the command${NC}\n" "${SHELL_RC}"
printf "\n"
