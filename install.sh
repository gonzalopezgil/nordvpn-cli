#!/usr/bin/env bash
# install.sh — nordvpn-cli installer for macOS and Linux
# shellcheck disable=SC2155
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/gonzalopezgil/nordvpn-cli/main/install.sh | bash
#   — or —
#   git clone https://github.com/gonzalopezgil/nordvpn-cli && cd nordvpn-cli && ./install.sh

set -euo pipefail

###############################################################################
# Config
###############################################################################
NORDVPN_DATA="${HOME}/.nordvpn"
OVPN_DIR="${NORDVPN_DATA}/ovpn"
HELPER_PATH="${NORDVPN_DATA}/nordvpn-helper"
SUDOERS_FILE="/etc/sudoers.d/nordvpn"
INSTALL_BIN="/usr/local/bin/nordvpn"
KEYCHAIN_ACCOUNT="nordvpn-service"
KEYCHAIN_SERVICE="nordvpn-openvpn"
OVPN_ARCHIVE_URL="https://downloads.nordcdn.com/configs/archives/servers/ovpn.zip"
REPO_RAW="https://raw.githubusercontent.com/gonzalopezgil/nordvpn-cli/main"

OS_TYPE=""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

_detect_os() {
    case "$(uname -s)" in
        Darwin) OS_TYPE="macos" ;;
        Linux)  OS_TYPE="linux" ;;
        *) _fail "Unsupported OS: $(uname -s). nordvpn supports macOS and Linux." ;;
    esac
}

_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════╗"
    echo "║  nordvpn-cli installer for $([ "$OS_TYPE" = "macos" ] && echo "macOS" || echo "Linux")   ║"
    echo "╚═══════════════════════════════════════╝"
    echo -e "${NC}"
}

_step()    { echo -e "${BOLD}▶ $*${NC}"; }
_ok()      { echo -e "  ${GREEN}✓${NC} $*"; }
_warn()    { echo -e "  ${YELLOW}⚠${NC}  $*"; }
_fail()    { echo -e "  ${RED}✗${NC} $*"; exit 1; }
_ask()     { echo -e "  ${CYAN}?${NC}  $*"; }

###############################################################################
# Checks
###############################################################################

check_platform() {
    _step "Checking platform..."
    _detect_os
    if [[ "$OS_TYPE" == "macos" ]]; then
        local ver
        ver=$(sw_vers -productVersion)
        _ok "macOS $ver"
    else
        local ver
        ver=$(lsb_release -ds 2>/dev/null || echo "Linux")
        _ok "$ver"
    fi
}

check_openvpn() {
    _step "Checking OpenVPN..."
    if command -v openvpn &>/dev/null; then
        _ok "OpenVPN found at $(command -v openvpn)"
        return
    fi
    
    _warn "OpenVPN not found. Installing..."
    
    if [[ "$OS_TYPE" == "macos" ]]; then
        if ! command -v brew &>/dev/null; then
            _fail "Homebrew not found. Install it first: https://brew.sh"
        fi
        brew install openvpn
    else
        if command -v apt &>/dev/null; then
            sudo apt-get update
            sudo apt-get install -y openvpn
        elif command -v yum &>/dev/null; then
            sudo yum install -y openvpn
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm openvpn
        else
            _fail "Could not detect package manager. Please install openvpn manually."
        fi
    fi
    
    _ok "OpenVPN installed ✓"
}

check_python() {
    _step "Checking Python 3..."
    if command -v python3 &>/dev/null; then
        _ok "Python 3 found"
        return
    fi
    _fail "Python 3 not found. Please install Python 3."
}

###############################################################################
# Install scripts
###############################################################################

install_scripts() {
    _step "Installing nordvpn and nordvpn-helper..."

    mkdir -p "$NORDVPN_DATA"

    # Detect if running from cloned repo or via curl
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-/dev/null}")" 2>/dev/null && pwd || echo "")"

    if [[ -n "$script_dir" && -f "${script_dir}/nordvpn" ]]; then
        # Install from local clone
        cp "${script_dir}/nordvpn"        "$INSTALL_BIN"
        cp "${script_dir}/nordvpn-helper" "$HELPER_PATH"
    else
        # Download from GitHub
        _warn "Downloading scripts from GitHub..."
        curl -fsSL --max-time 30 "${REPO_RAW}/nordvpn"        -o "$INSTALL_BIN"
        curl -fsSL --max-time 30 "${REPO_RAW}/nordvpn-helper" -o "$HELPER_PATH"
    fi

    chmod +x "$INSTALL_BIN"
    chmod +x "$HELPER_PATH"
    chmod 755 "$NORDVPN_DATA"

    _ok "nordvpn → $INSTALL_BIN"
    _ok "nordvpn-helper → $HELPER_PATH"
}

###############################################################################
# Sudoers
###############################################################################

install_sudoers() {
    _step "Installing sudoers entry..."
    _warn "This grants passwordless sudo access to nordvpn-helper ONLY (no broader root access)."
    _warn "You will be prompted for your sudo password once."
    echo ""

    local username
    username=$(whoami)
    local sudoers_content
    sudoers_content="${username} ALL=(root) NOPASSWD: ${HELPER_PATH} *"

    # Write to temp file, validate with visudo, then install
    local tmp_sudoers
    tmp_sudoers=$(mktemp)
    echo "$sudoers_content" > "$tmp_sudoers"

    sudo visudo -c -f "$tmp_sudoers" &>/dev/null || {
        rm -f "$tmp_sudoers"
        _fail "Sudoers syntax error — please report this as a bug."
    }

    sudo cp "$tmp_sudoers" "$SUDOERS_FILE"
    sudo chmod 440 "$SUDOERS_FILE"
    rm -f "$tmp_sudoers"

    _ok "Sudoers entry installed: $SUDOERS_FILE"
    _warn "Verify it with: sudo visudo -c -f $SUDOERS_FILE"
}

###############################################################################
# Download OpenVPN configs
###############################################################################

download_configs() {
    _step "Downloading OpenVPN server configs (~160MB)..."
    _warn "NordVPN provides thousands of server configs. This may take a minute."
    echo ""

    mkdir -p "$OVPN_DIR"
    cd "$OVPN_DIR"

    curl -fL --max-time 300 --progress-bar -o ovpn.zip "$OVPN_ARCHIVE_URL" || \
        _fail "Download failed. Check your internet connection."

    echo ""
    _ok "Download complete. Extracting..."
    unzip -q -o ovpn.zip
    rm ovpn.zip

    local udp_count tcp_count
    udp_count=$(find ovpn_udp -name '*.ovpn' 2>/dev/null | wc -l | tr -d ' ')
    tcp_count=$(find ovpn_tcp -name '*.ovpn' 2>/dev/null | wc -l | tr -d ' ')
    _ok "$udp_count UDP + $tcp_count TCP server configs downloaded ✓"
}

###############################################################################
# Credentials
###############################################################################

setup_credentials() {
    _step "Setting up NordVPN service credentials..."
    echo ""
    echo "  These are NOT your NordVPN account login credentials."
    echo "  Get them at: https://my.nordaccount.com/dashboard/nordvpn/manual-configuration/"
    echo "  → Click 'Service credentials' tab → copy username + password"
    echo ""

    local username password

    _ask "NordVPN service username:"
    read -r username

    _ask "NordVPN service password (input hidden):"
    read -rs password
    echo ""

    [[ -n "$username" && -n "$password" ]] || _fail "Username and password are required."

    if [[ "$OS_TYPE" == "macos" ]]; then
        # Store in Keychain
        security add-generic-password \
            -a "$KEYCHAIN_ACCOUNT" \
            -s "$KEYCHAIN_SERVICE" \
            -w "${username}:${password}" \
            -U 2>/dev/null || \
        security add-generic-password \
            -a "$KEYCHAIN_ACCOUNT" \
            -s "$KEYCHAIN_SERVICE" \
            -w "${username}:${password}" 2>/dev/null || \
            _fail "Failed to store credentials in Keychain."
        _ok "Credentials stored in macOS Keychain ✓"
    else
        # Store in file with restricted permissions
        mkdir -p "$NORDVPN_DATA"
        chmod 700 "$NORDVPN_DATA"
        printf '%s\n%s\n' "$username" "$password" > "${NORDVPN_DATA}/credentials"
        chmod 600 "${NORDVPN_DATA}/credentials"
        _ok "Credentials stored in ${NORDVPN_DATA}/credentials (chmod 600) ✓"
    fi
}

###############################################################################
# Verify installation
###############################################################################

verify() {
    _step "Verifying installation..."

    if command -v nordvpn &>/dev/null; then _ok "nordvpn command available"; else _warn "nordvpn not in PATH"; fi
    if [[ -f "$HELPER_PATH" ]]; then _ok "nordvpn-helper installed"; else _warn "nordvpn-helper not found at $HELPER_PATH"; fi
    if [[ -f "$SUDOERS_FILE" ]]; then _ok "Sudoers entry installed"; else _warn "Sudoers entry missing"; fi
    if [[ -d "${OVPN_DIR}/ovpn_udp" ]]; then _ok "OpenVPN configs present"; else _warn "No configs at $OVPN_DIR"; fi

    if [[ "$OS_TYPE" == "macos" ]]; then
        if security find-generic-password -a "$KEYCHAIN_ACCOUNT" -s "$KEYCHAIN_SERVICE" &>/dev/null; then
            _ok "Keychain credentials present"
        else
            _warn "No credentials in Keychain"
        fi
    else
        if [[ -f "${NORDVPN_DATA}/credentials" ]]; then
            _ok "Credentials file present"
        else
            _warn "No credentials file"
        fi
    fi
}

###############################################################################
# Summary
###############################################################################

print_summary() {
    echo ""
    echo -e "${GREEN}${BOLD}Installation complete! 🎉${NC}"
    echo ""
    echo "  Quick start:"
    echo "    nordvpn setup             # Interactive setup"
    echo "    nordvpn connect           # Connect to Spain (default)"
    echo "    nordvpn connect US        # Connect to United States"
    echo "    nordvpn status            # Check connection status"
    echo "    nordvpn disconnect        # Disconnect"
    echo ""
    echo "  If something goes wrong:"
    echo "    nordvpn fix               # Kill VPN + restore routes"
    echo "    cat /tmp/nordvpn-openvpn.log  # View OpenVPN logs"
    echo ""
    echo "  Uninstall:"
    if [[ "$OS_TYPE" == "macos" ]]; then
        echo "    sudo rm /usr/local/bin/nordvpn /etc/sudoers.d/nordvpn"
        echo "    rm -rf ~/.nordvpn"
        echo "    security delete-generic-password -a nordvpn-service -s nordvpn-openvpn"
    else
        echo "    sudo rm /usr/local/bin/nordvpn /etc/sudoers.d/nordvpn"
        echo "    rm -rf ~/.nordvpn"
    fi
    echo ""
}

###############################################################################
# Main
###############################################################################
main() {
    _banner

    check_platform
    check_openvpn
    check_python
    install_scripts
    install_sudoers
    download_configs
    setup_credentials
    verify
    print_summary
}

main "$@"
