#!/usr/bin/env bash
#
# setup-yt2jellyfin.sh - Install and configure yt2jellyfin
#

set -euo pipefail

# Colors (using printf for macOS compatibility)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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
# STEP 1: Install system dependencies
# ══════════════════════════════════════════════════════════════════════════════

log_info "Step 1: Installing system dependencies..."

OS_TYPE="$(uname -s)"

if [ "$OS_TYPE" = "Darwin" ]; then
    # macOS
    if command -v brew &> /dev/null; then
        log_info "Detected macOS with Homebrew"
        brew install ffmpeg python3 || true
    else
        log_warn "Homebrew not found. Install it from https://brew.sh"
        log_warn "Then run: brew install ffmpeg python3"
    fi
elif command -v apt &> /dev/null; then
    sudo apt update
    sudo apt install -y ffmpeg python3 python3-pip python3-venv
elif command -v dnf &> /dev/null; then
    sudo dnf install -y ffmpeg python3 python3-pip
elif command -v pacman &> /dev/null; then
    sudo pacman -S --noconfirm ffmpeg python python-pip
else
    log_warn "Unknown package manager. Please install ffmpeg and python3 manually."
fi

log_success "System dependencies installed"

# ══════════════════════════════════════════════════════════════════════════════
# STEP 2: Install yt-dlp and mutagen
# ══════════════════════════════════════════════════════════════════════════════

log_info "Step 2: Installing yt-dlp and mutagen..."

# On macOS, prefer Homebrew for yt-dlp (handles PATH automatically)
if [ "$OS_TYPE" = "Darwin" ] && command -v brew &> /dev/null; then
    brew install yt-dlp || brew upgrade yt-dlp || true
    pip3 install --user mutagen --break-system-packages 2>/dev/null || \
    pip3 install --user mutagen || true
elif command -v pipx &> /dev/null; then
    # Try pipx first (cleaner isolation)
    pipx install yt-dlp || pipx upgrade yt-dlp
    pipx inject yt-dlp mutagen || true
else
    # Fall back to pip --user
    pip3 install --user --upgrade yt-dlp mutagen --break-system-packages 2>/dev/null || \
    pip3 install --user --upgrade yt-dlp mutagen || \
    pip install --user --upgrade yt-dlp mutagen
fi

# ═══ CRITICAL: Add common bin directories to PATH before verification ═══
# pip --user installs to ~/.local/bin on Linux and ~/Library/Python/X.Y/bin on macOS
export PATH="$HOME/.local/bin:$PATH"

if [ "$OS_TYPE" = "Darwin" ]; then
    # macOS: also add Python user bin
    PYTHON_USER_BIN=$(python3 -c "import site; print(site.USER_BASE + '/bin')" 2>/dev/null || echo "")
    if [ -n "$PYTHON_USER_BIN" ] && [ -d "$PYTHON_USER_BIN" ]; then
        export PATH="$PYTHON_USER_BIN:$PATH"
    fi
fi

# Verify yt-dlp is accessible
if command -v yt-dlp &> /dev/null; then
    log_success "yt-dlp $(yt-dlp --version) installed"
else
    log_error "yt-dlp installation failed. Please install manually:"
    log_info "  pip3 install --user yt-dlp mutagen"
    log_info "  export PATH=\"\$HOME/.local/bin:\$PATH\""
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

    # Detect shell config file
    SHELL_RC=""
    if [ -n "${ZSH_VERSION:-}" ] || [[ "$SHELL" == *"zsh"* ]]; then
        SHELL_RC="$HOME/.zshrc"
    elif [[ "$SHELL" == *"bash"* ]]; then
        # On Linux prefer .bashrc, on macOS prefer .bash_profile
        if [ "$OS_TYPE" = "Darwin" ]; then
            SHELL_RC="$HOME/.bash_profile"
        else
            SHELL_RC="$HOME/.bashrc"
        fi
    elif [ -f "$HOME/.bashrc" ]; then
        SHELL_RC="$HOME/.bashrc"
    elif [ -f "$HOME/.bash_profile" ]; then
        SHELL_RC="$HOME/.bash_profile"
    fi

    # Default to .bashrc if nothing found
    SHELL_RC="${SHELL_RC:-$HOME/.bashrc}"

    if [ -n "$SHELL_RC" ]; then
        # Create file if it doesn't exist
        if [ ! -f "$SHELL_RC" ]; then
            touch "$SHELL_RC"
        fi

        # Check if we can write to the file
        if [ -w "$SHELL_RC" ]; then
            # Only add if not already present
            if ! grep -q 'yt2jellyfin' "$SHELL_RC" 2>/dev/null; then
                {
                    printf "\n"
                    printf "# yt2jellyfin\n"
                    printf 'export PATH="$HOME/.local/bin:$PATH"\n'
                } >> "$SHELL_RC"
                log_info "Added PATH to $SHELL_RC"
                log_warn "Run 'source $SHELL_RC' or restart your terminal"
            fi
        else
            log_warn "Cannot write to $SHELL_RC (permission denied)"
            log_info "Manually add this to your shell config:"
            printf '  export PATH="$HOME/.local/bin:$PATH"\n'
        fi
    fi
fi

# Also add Python user bin to PATH for macOS (if using pip instead of brew)
if [ "$OS_TYPE" = "Darwin" ] && [ -n "${PYTHON_USER_BIN:-}" ]; then
    if [ -n "$SHELL_RC" ] && { [ -w "$SHELL_RC" ] || [ ! -f "$SHELL_RC" ]; }; then
        if ! grep -q "Library/Python" "$SHELL_RC" 2>/dev/null; then
            {
                printf "# Python user bin (for pip packages)\n"
                printf 'export PATH="%s:$PATH"\n' "$PYTHON_USER_BIN"
            } >> "$SHELL_RC"
        fi
    fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# STEP 4: Configure defaults (optional)
# ══════════════════════════════════════════════════════════════════════════════

log_info "Step 4: Configuration..."

printf "\n"
read -p "Enter your Jellyfin music library path (or press Enter for ~/Music/YouTube): " MUSIC_PATH
MUSIC_PATH="${MUSIC_PATH:-$HOME/Music/YouTube}"

# Create the directory
mkdir -p "$MUSIC_PATH"

# Add environment variable to shell config
if [ -n "$SHELL_RC" ] && [ -w "$SHELL_RC" ]; then
    if ! grep -q "YT2JELLYFIN_OUTPUT" "$SHELL_RC" 2>/dev/null; then
        {
            printf "\n"
            printf "# yt2jellyfin default output directory\n"
            printf 'export YT2JELLYFIN_OUTPUT="%s"\n' "$MUSIC_PATH"
        } >> "$SHELL_RC"
    fi
else
    log_warn "Cannot write to shell config"
    log_info "Manually add: export YT2JELLYFIN_OUTPUT=\"$MUSIC_PATH\""
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
printf "${YELLOW}Note: Restart your terminal or run 'source %s' to use the command${NC}\n" "${SHELL_RC:-~/.bashrc}"
printf "\n"
