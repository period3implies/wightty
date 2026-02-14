#!/bin/bash
#
# Wightty (Ghostty fork) build & install script for Ubuntu 20.04+
#
# This script:
#   1. Installs system dependencies (via apt + PPAs for older Ubuntu)
#   2. Installs the correct Zig version
#   3. Clones and builds Wightty
#   4. Installs to /usr/local
#   5. Installs your personal config
#
# Usage:
#   chmod +x install-ubuntu.sh
#   sudo ./install-ubuntu.sh        # or run with a user that has sudo
#
set -euo pipefail

REPO_URL="https://github.com/period3implies/wightty.git"
REPO_BRANCH="main"
BUILD_DIR="/tmp/wightty-build"
ZIG_VERSION="0.15.2"
INSTALL_PREFIX="/usr/local"

# ---------- helpers ----------

log()  { echo -e "\n\033[1;34m==>\033[0m \033[1m$*\033[0m"; }
warn() { echo -e "\033[1;33mWARN:\033[0m $*"; }
die()  { echo -e "\033[1;31mERROR:\033[0m $*" >&2; exit 1; }

need_root() {
    if [ "$EUID" -ne 0 ]; then
        die "This script must be run as root (use sudo)."
    fi
}

# ---------- detect distro ----------

detect_ubuntu_version() {
    if [ ! -f /etc/os-release ]; then
        die "Cannot detect OS version. Is this Ubuntu?"
    fi
    . /etc/os-release
    UBUNTU_VERSION="${VERSION_ID:-unknown}"
    UBUNTU_CODENAME="${VERSION_CODENAME:-unknown}"
    log "Detected: $PRETTY_NAME ($UBUNTU_CODENAME)"
}

# ---------- dependencies ----------

install_deps() {
    log "Installing system dependencies..."

    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq

    # Core build tools available on all Ubuntu versions
    apt-get install -y -qq --no-install-recommends \
        build-essential \
        curl \
        ca-certificates \
        git \
        pkg-config \
        pandoc \
        libbz2-dev \
        libonig-dev \
        libxml2-utils \
        gettext

    # GTK 4 and libadwaita: available natively on 22.04+
    # On 20.04 we need a PPA
    local major_ver="${UBUNTU_VERSION%%.*}"
    if [ "$major_ver" -lt 22 ]; then
        log "Ubuntu $UBUNTU_VERSION detected — adding PPA for GTK 4 + libadwaita..."
        apt-get install -y -qq --no-install-recommends software-properties-common
        add-apt-repository -y ppa:nicotine-team/gtk-4 || true
        apt-get update -qq
    fi

    apt-get install -y -qq --no-install-recommends \
        libgtk-4-dev \
        libadwaita-1-dev

    # gtk4-layer-shell (for Wayland layer shell support)
    # May not be available on older distros — optional
    apt-get install -y -qq --no-install-recommends \
        libgtk4-layer-shell-dev 2>/dev/null || \
        warn "libgtk4-layer-shell-dev not available — Wayland layer shell features disabled."

    # blueprint-compiler: needs 0.16.0+, may not be in repos
    install_blueprint_compiler
}

install_blueprint_compiler() {
    # Check if a suitable version is already installed
    if command -v blueprint-compiler &>/dev/null; then
        local ver
        ver=$(blueprint-compiler --version 2>/dev/null || echo "0")
        local minor
        minor=$(echo "$ver" | cut -d. -f2)
        if [ "${minor:-0}" -ge 16 ]; then
            log "blueprint-compiler $ver already installed (>= 0.16.0)"
            return
        fi
    fi

    log "Installing blueprint-compiler via pip..."
    apt-get install -y -qq --no-install-recommends python3-pip
    pip3 install blueprint-compiler 2>/dev/null || \
    pip3 install --break-system-packages blueprint-compiler 2>/dev/null || {
        warn "pip install failed, trying apt version..."
        apt-get install -y -qq blueprint-compiler || \
            die "Could not install blueprint-compiler >= 0.16.0"
    }
}

# ---------- zig ----------

install_zig() {
    if command -v zig &>/dev/null; then
        local current
        current=$(zig version 2>/dev/null || echo "0")
        if [ "$current" = "$ZIG_VERSION" ]; then
            log "Zig $ZIG_VERSION already installed"
            return
        fi
    fi

    log "Installing Zig $ZIG_VERSION..."
    local arch
    arch=$(uname -m)
    # Zig uses x86_64/aarch64
    case "$arch" in
        x86_64|aarch64) ;;
        arm64) arch="aarch64" ;;
        *) die "Unsupported architecture: $arch" ;;
    esac

    local zig_tarball="zig-linux-${arch}-${ZIG_VERSION}.tar.xz"
    local zig_url="https://ziglang.org/download/${ZIG_VERSION}/${zig_tarball}"

    curl -L -o "/tmp/${zig_tarball}" "$zig_url"
    rm -rf /opt/zig
    mkdir -p /opt/zig
    tar -xf "/tmp/${zig_tarball}" -C /opt/zig --strip-components=1
    rm "/tmp/${zig_tarball}"
    ln -sf /opt/zig/zig /usr/local/bin/zig

    log "Zig $(zig version) installed"
}

# ---------- clone & build ----------

clone_repo() {
    log "Cloning Wightty..."
    rm -rf "$BUILD_DIR"
    git clone --depth 1 --branch "$REPO_BRANCH" "$REPO_URL" "$BUILD_DIR"
}

build_wightty() {
    log "Building Wightty (ReleaseFast)... this may take a while."
    cd "$BUILD_DIR"

    zig build \
        --prefix "$INSTALL_PREFIX" \
        -Doptimize=ReleaseFast \
        -Dcpu=baseline \
        --verbose 2>&1 | tail -5 || true

    # Verify build succeeded
    if [ ! -f zig-out/bin/ghostty ]; then
        die "Build failed — no binary produced."
    fi

    log "Build complete: $(zig-out/bin/ghostty +version 2>/dev/null || echo 'ok')"
}

# ---------- install ----------

install_wightty() {
    log "Installing to ${INSTALL_PREFIX}..."
    cd "$BUILD_DIR"

    # Binary
    install -Dm755 zig-out/bin/ghostty "${INSTALL_PREFIX}/bin/wightty"

    # Terminfo
    if [ -d zig-out/share/terminfo ]; then
        cp -r zig-out/share/terminfo "${INSTALL_PREFIX}/share/"
    fi

    # Shell integration, themes, man pages
    if [ -d zig-out/share/ghostty ]; then
        mkdir -p "${INSTALL_PREFIX}/share/wightty"
        cp -r zig-out/share/ghostty/* "${INSTALL_PREFIX}/share/wightty/"
    fi

    if [ -d zig-out/share/man ]; then
        cp -r zig-out/share/man "${INSTALL_PREFIX}/share/"
    fi

    # Desktop file
    if [ -f zig-out/share/applications/*.desktop ] 2>/dev/null; then
        mkdir -p "${INSTALL_PREFIX}/share/applications"
        cp zig-out/share/applications/*.desktop "${INSTALL_PREFIX}/share/applications/"
    fi

    # Icons
    if [ -d zig-out/share/icons ]; then
        cp -r zig-out/share/icons "${INSTALL_PREFIX}/share/"
    fi

    # Update icon cache and desktop database
    gtk-update-icon-cache "${INSTALL_PREFIX}/share/icons/hicolor" 2>/dev/null || true
    update-desktop-database "${INSTALL_PREFIX}/share/applications" 2>/dev/null || true
}

# ---------- config ----------

install_config() {
    log "Installing Wightty config..."

    # Config goes in the calling user's home, not root's
    local target_user="${SUDO_USER:-$USER}"
    local target_home
    target_home=$(eval echo "~${target_user}")
    local config_dir="${target_home}/.config/ghostty"

    mkdir -p "$config_dir"

    cat > "${config_dir}/config" << 'GHOSTTY_CONFIG'
# Wightty configuration
# Synced from macOS config — adjust Linux-specific options as needed

# ============================================================
# Font
# ============================================================
# On Linux, install: sudo apt install fonts-meslo (or download Nerd Font)
# font-family = MesloLGM Nerd Font Mono
font-family = Monospace
font-size = 14

# ============================================================
# Theme & colors
# ============================================================
theme = Catppuccin Mocha

# ============================================================
# Window appearance
# ============================================================
background-opacity = 0.88
window-padding-x = 12
window-padding-y = 8
window-save-state = always

# ============================================================
# Cursor
# ============================================================
cursor-style = bar
cursor-style-blink = false

# ============================================================
# Misc
# ============================================================
copy-on-select = clipboard
mouse-hide-while-typing = true
GHOSTTY_CONFIG

    chown -R "${target_user}:" "$config_dir"
    log "Config written to ${config_dir}/config"
}

# ---------- cleanup ----------

cleanup() {
    log "Cleaning up build directory..."
    rm -rf "$BUILD_DIR"
}

# ---------- main ----------

main() {
    need_root
    detect_ubuntu_version
    install_deps
    install_zig
    clone_repo
    build_wightty
    install_wightty
    install_config
    cleanup

    log "Wightty installed successfully!"
    echo ""
    echo "  Run with:  wightty"
    echo "  Config at: ~/.config/ghostty/config"
    echo ""
}

main "$@"
