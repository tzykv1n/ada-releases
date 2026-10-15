#!/usr/bin/env bash
# ==============================================================================
# ADA Installation and Distribution Script
#
# Supports:
#   1. Local installation from source: ./install.sh
#   2. Public release installation:
#      curl -fsSL https://raw.githubusercontent.com/tzykv1n/ada-releases/master/install.sh | bash
#
# Features:
#   - 100% Authentication-free: downloads versioned assets from public distribution repository.
#   - Cryptographic verification: validates SHA-256 checksums before unpacking or executing.
#   - Path traversal prevention: extracts into isolated user space (~/.local/share/ada).
#   - Complete non-root execution: requires zero sudo or administrator privileges.
#   - Clean upgrade and uninstall paths.
#
# Flags:
#   --help, -h          Show this help message
#   --version <ver>     Specify explicit ADA release version (default: 0.3.0)
#   --dry-run           Probe hardware and environment, display planned actions without changes
#   --yes, -y           Non-interactive mode (automatically accept confirmations)
#   --no-gpu            Install minimal/CPU-only dependencies without heavy GPU packages
#   --dev               Install developer tools (pytest, ruff, mypy, build)
#   --configure-path    Permit installer to automatically add ~/.local/bin to shell rc
#   --uninstall         Safely remove ADA binary and isolated environment
# ==============================================================================

set -eu
[ -n "${BASH_VERSION:-}" ] && set -o pipefail 2>/dev/null || true

DEFAULT_VERSION="0.3.0"
ADA_RELEASE_VERSION="${DEFAULT_VERSION}"
PUBLIC_DIST_REPO="tzykv1n/ada-releases"

# Colors (disabled if NO_COLOR is set or stdout is not a tty)
if [ -z "${NO_COLOR:-}" ] && [ -t 1 ]; then
    BOLD="\033[1m"
    GREEN="\033[32m"
    YELLOW="\033[33m"
    CYAN="\033[36m"
    RED="\033[31m"
    RESET="\033[0m"
else
    BOLD=""
    GREEN=""
    YELLOW=""
    CYAN=""
    RED=""
    RESET=""
fi

DRY_RUN=0
AUTO_YES=0
NO_GPU=0
DEV_MODE=0
CONFIGURE_PATH=0
DO_UNINSTALL=0

EXPLICIT_VERSION=0

# Parse arguments
while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            printf "%b\n" "${BOLD}ADA Platform Installer (v${ADA_RELEASE_VERSION})${RESET}"
            printf "\nUsage: install.sh [options]\n\n"
            printf "Options:\n"
            printf "  -h, --help            Show this help message\n"
            printf "  --version <ver>       Install specific versioned release (e.g. 0.3.0)\n"
            printf "  --dry-run             Probe system and print installation plan without making changes\n"
            printf "  -y, --yes             Assume yes for all prompts (unattended mode)\n"
            printf "  --no-gpu              Install CPU-only mode without heavy GPU packages\n"
            printf "  --dev                 Include developer dependencies (pytest, ruff, mypy)\n"
            printf "  --configure-path      Allow updating shell startup files for PATH\n"
            printf "  --uninstall           Remove ADA installation and launcher binary\n\n"
            exit 0
            ;;
        --version)
            if [ -n "${2:-}" ] && [[ "$2" != --* ]]; then
                ADA_RELEASE_VERSION="${2#v}"
                EXPLICIT_VERSION=1
                shift 2
            else
                printf "%b\n" "${RED}[ERROR] --version requires a version argument (e.g. 0.3.0)${RESET}" >&2
                exit 1
            fi
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        -y|--yes)
            AUTO_YES=1
            shift
            ;;
        --no-gpu)
            NO_GPU=1
            shift
            ;;
        --dev)
            DEV_MODE=1
            shift
            ;;
        --configure-path)
            CONFIGURE_PATH=1
            shift
            ;;
        --uninstall)
            DO_UNINSTALL=1
            shift
            ;;
        *)
            printf "%b\n" "${RED}[ERROR] Unknown option: $1${RESET}" >&2
            printf "Use --help for usage instructions.\n"
            exit 1
            ;;
    esac
done

LOCAL_SHARE="${HOME}/.local/share/ada"
LOCAL_BIN="${HOME}/.local/bin"
VENV_PATH="${LOCAL_SHARE}/venv"
ADA_BIN="${LOCAL_BIN}/ada"

# Handle Uninstall
if [ "$DO_UNINSTALL" -eq 1 ]; then
    printf "%b\n" "${BOLD}Uninstalling ADA Platform...${RESET}"
    if [ "$DRY_RUN" -eq 1 ]; then
        printf "[DRY RUN] Would remove %s and %s\n" "$ADA_BIN" "$LOCAL_SHARE"
        exit 0
    fi
    rm -f "$ADA_BIN"
    rm -rf "$LOCAL_SHARE"
    printf "%b\n" "${GREEN}✓ Successfully uninstalled ADA.${RESET}"
    printf "User data and Kaggle cache in ~/.cache/ada or XDG state remain preserved.\n"
    exit 0
fi

printf "%b\n" "${BOLD}${CYAN}────────────────────────────────────────────────────────────────${RESET}"
printf "%b\n" "${BOLD}${CYAN} ADA — Adaptive Research Platform Installer (v${ADA_RELEASE_VERSION})${RESET}"
printf "%b\n" "${BOLD}${CYAN}────────────────────────────────────────────────────────────────${RESET}"

# 1. Detect OS & Architecture
OS_NAME="$(uname -s 2>/dev/null || echo "Unknown")"
ARCH_NAME="$(uname -m 2>/dev/null || echo "Unknown")"
printf "  • Platform:        %b (%s)\n" "${GREEN}${OS_NAME}${RESET}" "${ARCH_NAME}"

if [ "$OS_NAME" != "Linux" ]; then
    printf "%b\n" "${YELLOW}Warning: ADA is formally validated on Linux. Continuing on best-effort basis.${RESET}"
fi

# 2. Detect Supported Python (>= 3.9)
PYTHON_BIN=""
for candidate in python3 python python3.14 python3.13 python3.12 python3.11 python3.10 python3.9; do
    if command -v "$candidate" >/dev/null 2>&1; then
        PY_MAJOR="$("$candidate" -c 'import sys; print(sys.version_info.major)' 2>/dev/null || true)"
        PY_MINOR="$("$candidate" -c 'import sys; print(sys.version_info.minor)' 2>/dev/null || true)"
        if [ "$PY_MAJOR" = "3" ] && [ "$PY_MINOR" -ge 9 ] 2>/dev/null; then
            PYTHON_BIN="$candidate"
            break
        fi
    fi
done

if [ -z "$PYTHON_BIN" ]; then
    printf "%b\n" "${RED}[ERROR] Python 3.9+ is required, but was not found on your system.${RESET}" >&2
    printf "Please install Python 3.10+ (via your system package manager) and re-run this script.\n"
    exit 1
fi

PY_FULL_VER="$("$PYTHON_BIN" --version 2>&1)"
printf "  • Detected Python: %b (%s)\n" "${GREEN}${PY_FULL_VER}${RESET}" "${PYTHON_BIN}"

# 3. Hardware Diagnostics
CPU_COUNT="$("$PYTHON_BIN" -c 'import os; print(os.cpu_count() or 1)' 2>/dev/null || echo "1")"
MEM_TOTAL=""
if [ -f /proc/meminfo ]; then
    MEM_TOTAL="$(awk '/MemTotal/ {printf "%.1f GB", $2/1024/1024}' /proc/meminfo 2>/dev/null || true)"
fi
if [ -z "$MEM_TOTAL" ]; then
    MEM_TOTAL="$("$PYTHON_BIN" -c 'import psutil; print(f"{psutil.virtual_memory().total / (1024**3):.1f} GB")' 2>/dev/null || echo "Unknown")"
fi
printf "  • Host Hardware:   %s CPU cores, %s RAM\n" "${CPU_COUNT}" "${MEM_TOTAL}"

HAS_NVIDIA=0
if command -v nvidia-smi >/dev/null 2>&1; then
    GPU_NAME="$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n 1 || echo "")"
    if [ -n "$GPU_NAME" ]; then
        HAS_NVIDIA=1
        printf "  • GPU Hardware:    %b\n" "${GREEN}NVIDIA ${GPU_NAME}${RESET}"
    fi
fi
if [ "$HAS_NVIDIA" -eq 0 ]; then
    printf "  • GPU Hardware:    CPU / None detected (Local CPU adaptive mode)\n"
fi

# 4. Check if script is run within an existing repository directory
SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
fi

REPO_DIR=""
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/pyproject.toml" ]; then
    REPO_DIR="$SCRIPT_DIR"
elif [ -f "./pyproject.toml" ]; then
    REPO_DIR="$(pwd)"
fi

if [ "$EXPLICIT_VERSION" -eq 0 ] && [ -z "$REPO_DIR" ]; then
    LATEST_TAG=""
    if command -v curl >/dev/null 2>&1; then
        LATEST_TAG="$(curl -fsSL --connect-timeout 4 "https://api.github.com/repos/${PUBLIC_DIST_REPO}/releases/latest" 2>/dev/null | grep '"tag_name":' | head -n 1 | sed -E 's/.*"tag_name":\s*"([^"]+)".*/\1/' || true)"
    elif command -v wget >/dev/null 2>&1; then
        LATEST_TAG="$(wget -qO- --timeout=4 "https://api.github.com/repos/${PUBLIC_DIST_REPO}/releases/latest" 2>/dev/null | grep '"tag_name":' | head -n 1 | sed -E 's/.*"tag_name":\s*"([^"]+)".*/\1/' || true)"
    fi
    if [ -n "$LATEST_TAG" ]; then
        ADA_RELEASE_VERSION="${LATEST_TAG#v}"
    fi
fi

RELEASE_BASE_URL="https://github.com/${PUBLIC_DIST_REPO}/releases/download/v${ADA_RELEASE_VERSION}"
TARBALL_FILENAME="ada-${ADA_RELEASE_VERSION}.tar.gz"
TARBALL_URL="${RELEASE_BASE_URL}/${TARBALL_FILENAME}"
CHECKSUM_URL="${RELEASE_BASE_URL}/checksums.sha256"

if [ -n "$REPO_DIR" ]; then
    printf "  • Install Source:  %b\n" "${CYAN}Local Checkout (${REPO_DIR})${RESET}"
else
    printf "  • Install Source:  %b\n" "${CYAN}Public Release v${ADA_RELEASE_VERSION} (${TARBALL_URL})${RESET}"
fi

printf "  • Target Venv:     %s\n" "${VENV_PATH}"
printf "  • Target Binary:   %s\n" "${ADA_BIN}"

# 5. PATH Verification
PATH_NEEDS_UPDATE=0
SHELL_NAME="$(basename "${SHELL:-bash}")"
RC_FILE=""

case "$SHELL_NAME" in
    zsh)
        RC_FILE="$HOME/.zshrc"
        ;;
    fish)
        RC_FILE="$HOME/.config/fish/config.fish"
        ;;
    *)
        RC_FILE="$HOME/.bashrc"
        ;;
esac

case ":$PATH:" in
    *":$LOCAL_BIN:"*)
        printf "  • PATH Status:     %b\n" "${GREEN}$LOCAL_BIN is in PATH${RESET}"
        ;;
    *)
        PATH_NEEDS_UPDATE=1
        printf "  • PATH Status:     %b\n" "${YELLOW}$LOCAL_BIN is not currently in PATH${RESET}"
        ;;
esac

printf "%b\n" "${BOLD}${CYAN}────────────────────────────────────────────────────────────────${RESET}"

# Handle Dry-Run
if [ "$DRY_RUN" -eq 1 ]; then
    printf "%b\n" "${BOLD}${YELLOW}[DRY RUN MODE]${RESET} Planned actions:"
    printf "  1. Ensure %s and %s directories exist.\n" "$LOCAL_SHARE" "$LOCAL_BIN"
    printf "  2. Create isolated Python virtual environment at %s.\n" "$VENV_PATH"
    if [ -n "$REPO_DIR" ]; then
        printf "  3. Install ADA from local directory %s.\n" "$REPO_DIR"
    else
        printf "  3. Download public release %s and verify SHA-256 against published checksum.\n" "$TARBALL_URL"
        printf "  4. Unpack into %s/src and install into isolated virtual environment.\n" "$LOCAL_SHARE"
    fi
    printf "  5. Symlink launcher binary %s -> %s.\n" "$VENV_PATH/bin/ada" "$ADA_BIN"
    if [ "$PATH_NEEDS_UPDATE" -eq 1 ]; then
        printf "  6. Guide user to configure PATH in %s (or with --configure-path).\n" "$RC_FILE"
    fi
    printf "  7. Run post-install health verification with 'ada system'.\n\n"
    printf "%b\n" "${GREEN}Dry run completed successfully. No changes were made.${RESET}"
    exit 0
fi

# Confirmation prompt if not unattended
if [ "$AUTO_YES" -eq 0 ]; then
    response=""
    if [ -t 0 ]; then
        printf "Proceed with installation? [Y/n] "
        read -r response || response="y"
    elif [ -r /dev/tty ]; then
        printf "Proceed with installation? [Y/n] "
        read -r response < /dev/tty || response="y"
    else
        response="y"
    fi

    case "$response" in
        [nN][oO]|[nN])
            printf "Installation cancelled by user.\n"
            exit 0
            ;;
        *)
            ;;
    esac
fi

# 6. Create Target Directories
printf "\n%b\n" "${BOLD}Setting up isolated ADA environment...${RESET}"
mkdir -p "$LOCAL_SHARE" "$LOCAL_BIN"

# 7. Create / Validate Virtual Environment
if [ ! -d "$VENV_PATH" ] || [ ! -f "$VENV_PATH/bin/python" ]; then
    printf "Creating isolated virtual environment at %s...\n" "$VENV_PATH"
    "$PYTHON_BIN" -m venv "$VENV_PATH"
fi

printf "Upgrading build tools in isolated environment...\n"
"$VENV_PATH/bin/pip" install --upgrade pip setuptools wheel >/dev/null 2>&1

# 8. Install ADA Package
EXTRAS="kaggle"
if [ "$DEV_MODE" -eq 1 ]; then
    EXTRAS="all"
fi

if [ -n "$REPO_DIR" ]; then
    printf "Installing ADA from local repository (%s)...\n" "$REPO_DIR"
    "$VENV_PATH/bin/pip" install -e "$REPO_DIR[$EXTRAS]"
    if [ "$DEV_MODE" -eq 1 ] && [ -d "$REPO_DIR/.git" ]; then
        if [ -f "$REPO_DIR/scripts/bump_version.py" ]; then
            printf "Setting up automated versioning Git hooks...\n"
            "$VENV_PATH/bin/python" "$REPO_DIR/scripts/bump_version.py" --install-hook 2>/dev/null || true
        fi
    fi
else
    # Remote Public Installation from Published Release Tarball
    DOWNLOAD_DIR="$(mktemp -d /tmp/ada-install-XXXXXX)"
    trap 'rm -rf "$DOWNLOAD_DIR"' EXIT

    TARBALL_PATH="$DOWNLOAD_DIR/$TARBALL_FILENAME"
    CHECKSUM_PATH="$DOWNLOAD_DIR/checksums.sha256"

    printf "Downloading release checksums from %s...\n" "$CHECKSUM_URL"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --retry 3 "$CHECKSUM_URL" -o "$CHECKSUM_PATH" || {
            printf "%b\n" "${RED}[ERROR] Failed to download checksums from ${CHECKSUM_URL}.${RESET}" >&2
            exit 1
        }
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$CHECKSUM_PATH" "$CHECKSUM_URL" || {
            printf "%b\n" "${RED}[ERROR] Failed to download checksums from ${CHECKSUM_URL}.${RESET}" >&2
            exit 1
        }
    else
        printf "%b\n" "${RED}[ERROR] Neither curl nor wget found. Please install curl or wget.${RESET}" >&2
        exit 1
    fi

    printf "Downloading release archive from %s...\n" "$TARBALL_URL"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --retry 3 "$TARBALL_URL" -o "$TARBALL_PATH" || {
            printf "%b\n" "${RED}[ERROR] Failed to download release tarball from ${TARBALL_URL}.${RESET}" >&2
            exit 1
        }
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$TARBALL_PATH" "$TARBALL_URL" || {
            printf "%b\n" "${RED}[ERROR] Failed to download release tarball from ${TARBALL_URL}.${RESET}" >&2
            exit 1
        }
    fi

    # 9. Verify Checksum
    printf "Verifying cryptographic SHA-256 checksum...\n"
    EXPECTED_SHA="$(grep "$TARBALL_FILENAME" "$CHECKSUM_PATH" | awk '{print $1}')"
    if [ -z "$EXPECTED_SHA" ]; then
        printf "%b\n" "${RED}[ERROR] Archive $TARBALL_FILENAME not listed in published checksums file!${RESET}" >&2
        exit 1
    fi

    ACTUAL_SHA="$("$PYTHON_BIN" -c "import hashlib; print(hashlib.sha256(open('$TARBALL_PATH', 'rb').read()).hexdigest())")"
    if [ "$EXPECTED_SHA" != "$ACTUAL_SHA" ]; then
        printf "%b\n" "${RED}[SECURITY ERROR] SHA-256 checksum verification failed!${RESET}" >&2
        printf "  Expected: %s\n" "$EXPECTED_SHA" >&2
        printf "  Actual:   %s\n" "$ACTUAL_SHA" >&2
        exit 1
    fi
    printf "%b\n" "${GREEN}✓ Checksum verified successfully (${ACTUAL_SHA:0:16}...)${RESET}"

    # 10. Extract Archive Safely
    EXTRACT_DEST="$LOCAL_SHARE/src"
    rm -rf "$EXTRACT_DEST"
    mkdir -p "$EXTRACT_DEST"

    printf "Extracting release files into %s...\n" "$EXTRACT_DEST"
    tar -xzf "$TARBALL_PATH" -C "$EXTRACT_DEST" --strip-components=1

    printf "Installing ADA into isolated environment...\n"
    "$VENV_PATH/bin/pip" install "$EXTRACT_DEST[$EXTRAS]"
fi

# 11. Link binary to ~/.local/bin/ada
ln -sf "$VENV_PATH/bin/ada" "$ADA_BIN"
chmod +x "$ADA_BIN"
printf "%b\n" "${GREEN}✓ Binary linked to $ADA_BIN${RESET}"

# 12. PATH Configuration Guidance
if [ "$PATH_NEEDS_UPDATE" -eq 1 ]; then
    if [ "$CONFIGURE_PATH" -eq 1 ]; then
        printf "\n%b\n" "${YELLOW}Configuring PATH in $RC_FILE...${RESET}"
        if [ "$SHELL_NAME" = "fish" ]; then
            mkdir -p "$(dirname "$RC_FILE")"
            if ! grep -q "fish_add_path ~/.local/bin" "$RC_FILE" 2>/dev/null; then
                printf "\n# ADA CLI PATH\nfish_add_path ~/.local/bin\n" >> "$RC_FILE"
                printf "%b\n" "${GREEN}✓ Added fish_add_path ~/.local/bin to $RC_FILE${RESET}"
            fi
        else
            if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$RC_FILE" 2>/dev/null; then
                printf '\n# ADA CLI PATH\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$RC_FILE"
                printf "%b\n" "${GREEN}✓ Added export PATH=\"\$HOME/.local/bin:\$PATH\" to $RC_FILE${RESET}"
            fi
        fi
        printf "%b\n" "${CYAN}Note: Run 'source $RC_FILE' or start a new terminal session to refresh PATH.${RESET}"
    else
        printf "\n%b\n" "${YELLOW}[NOTE] PATH Configuration:${RESET}"
        printf "  %s is not currently in your system PATH.\n" "$LOCAL_BIN"
        printf "  To enable 'ada' command globally, add the following line to your %s:\n" "$RC_FILE"
        printf "%b\n" "    ${BOLD}export PATH=\"\$HOME/.local/bin:\$PATH\"${RESET}"
        printf "  Alternatively, re-run with %b to permit automatic configuration.\n" "${CYAN}--configure-path${RESET}"
    fi
fi

# 13. Post-Installation Health Check
printf "\n%b\n" "${BOLD}Running post-install health verification...${RESET}"
if [ ! -x "$ADA_BIN" ]; then
    printf "%b\n" "${RED}[ERROR] Installed binary $ADA_BIN is not executable!${RESET}" >&2
    exit 1
fi

if ! "$ADA_BIN" --version >/dev/null 2>&1; then
    printf "%b\n" "${RED}[ERROR] Health check failed: 'ada --version' returned non-zero exit code!${RESET}" >&2
    exit 1
fi

VER_OUTPUT="$("$ADA_BIN" --version 2>&1)"
printf "%b\n" "${GREEN}✓ Health verification passed: ${VER_OUTPUT}${RESET}"

printf "\n%b\n" "${BOLD}${GREEN}ADA installation complete!${RESET}"
printf "You can now run:\n"
printf "  %b            Launch the interactive terminal interface\n" "${BOLD}ada${RESET}"
printf "  %b     Show system diagnostics and hardware profile\n" "${BOLD}ada system${RESET}"
printf "  %b        Run Stage 1 Adaptive Reasoning\n" "${BOLD}ada run${RESET}"
printf "  %b    View verified evaluation benchmarks\n\n" "${BOLD}ada results${RESET}"

exit 0
