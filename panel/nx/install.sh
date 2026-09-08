#!/usr/bin/env bash

# ============================================================
#                         NX DACTYL
#                  One-Click Installer
# ============================================================

set -u

# ---------------- COLORS ----------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'

# ---------------- PATHS -----------------

PANEL_DIR="/var/www/NX"
WINGS_DIR="/var/www/NX-WINGS"
DASH_DIR="/var/www/NX-DASH"

PANEL_REPO="https://github.com/NyroxYT/NX.git"
WINGS_REPO="https://github.com/NyroxYT/NX-WINGS.git"
DASH_REPO="https://github.com/NyroxYT/NX-DASH.git"

CLOUDFLARE_SCRIPT="https://raw.githubusercontent.com/NyroxYT/NyroxHub/refs/heads/main/toolbox/cloudflare.sh"

# ---------------- HELPERS ----------------

pause_screen() {
    echo
    read -rp "  Press ENTER to continue..."
}

header() {
    clear

    echo -e "${PURPLE}"
    cat <<'EOF'
███╗   ██╗██╗  ██╗    ██████╗  █████╗  ██████╗████████╗██╗   ██╗██╗
████╗  ██║╚██╗██╔╝    ██╔══██╗██╔══██╗██╔════╝╚══██╔══╝╚██╗ ██╔╝██║
██╔██╗ ██║ ╚███╔╝     ██║  ██║███████║██║        ██║    ╚████╔╝ ██║
██║╚██╗██║ ██╔██╗     ██║  ██║██╔══██║██║        ██║     ╚██╔╝  ██║
██║ ╚████║██╔╝ ██╗    ██████╔╝██║  ██║╚██████╗   ██║      ██║   ██║
╚═╝  ╚═══╝╚═╝  ╚═╝    ╚═════╝ ╚═╝  ╚═╝ ╚═════╝   ╚═╝      ╚═╝   ╚═╝
EOF
    echo -e "${NC}"

    echo -e "${CYAN}                         [ NX DACTYL ]${NC}"
    echo -e "${GRAY}                  Hosting Control Utility${NC}"
    echo
}

success() {
    echo -e "  ${GREEN}[✓]${NC} $1"
}

error() {
    echo -e "  ${RED}[✗]${NC} $1"
}

info() {
    echo -e "  ${CYAN}[INFO]${NC} $1"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# ---------------- ROOT CHECK ----------------

root_check() {
    if [[ "$(id -u)" -ne 0 ]]; then
        error "NX DACTYL must be run as root."
        echo
        echo "  Run:"
        echo "  sudo ./NX.sh"
        exit 1
    fi
}

# ---------------- DEPENDENCIES ----------------

install_dependencies() {

    info "Installing required dependencies..."

    if command_exists apt-get; then
        apt-get update -qq

        apt-get install -y \
            git \
            curl \
            wget \
            ca-certificates \
            build-essential \
            openssl \
            nginx \
            >/dev/null 2>&1

    elif command_exists dnf; then

        dnf install -y \
            git \
            curl \
            wget \
            ca-certificates \
            gcc \
            openssl \
            nginx \
            >/dev/null 2>&1

    elif command_exists yum; then

        yum install -y \
            git \
            curl \
            wget \
            ca-certificates \
            gcc \
            openssl \
            nginx \
            >/dev/null 2>&1
    fi

    success "Dependencies installed."
}

# ---------------- PANEL ----------------

install_panel() {

    header

    echo -e "${WHITE}  INSTALL NX PANEL${NC}"
    echo -e "${GRAY}  ─────────────────────────────────────────────${NC}"
    echo

    install_dependencies

    if [[ -d "$PANEL_DIR/.git" ]]; then

        info "NX Panel already exists."
        info "Updating repository..."

        git -C "$PANEL_DIR" pull --ff-only

    else

        info "Cloning NX Panel..."

        mkdir -p "$(dirname "$PANEL_DIR")"

        git clone "$PANEL_REPO" "$PANEL_DIR"
    fi

    cd "$PANEL_DIR" || exit 1

    if command_exists npm; then
        info "Installing Node dependencies..."
        npm install
    else
        error "npm is not installed."
        pause_screen
        return
    fi

    success "NX Panel installation completed."

    echo
    echo -e "${CYAN}Panel directory:${NC} $PANEL_DIR"

    pause_screen
}

# ---------------- WINGS ----------------

install_wings() {

    header

    echo -e "${WHITE}  INSTALL NX WINGS${NC}"
    echo -e "${GRAY}  ─────────────────────────────────────────────${NC}"
    echo

    install_dependencies

    if [[ -d "$WINGS_DIR/.git" ]]; then

        info "NX-WINGS already exists."
        info "Updating repository..."

        git -C "$WINGS_DIR" pull --ff-only

    else

        info "Cloning NX-WINGS..."

        mkdir -p "$(dirname "$WINGS_DIR")"

        git clone "$WINGS_REPO" "$WINGS_DIR"
    fi

    cd "$WINGS_DIR" || exit 1

    if ! command_exists go; then
        info "Go is not installed."

        if command_exists apt-get; then
            apt-get install -y golang >/dev/null 2>&1
        elif command_exists dnf; then
            dnf install -y golang >/dev/null 2>&1
        elif command_exists yum; then
            yum install -y golang >/dev/null 2>&1
        fi
    fi

    if command_exists go; then
        info "Building NX-WINGS..."
        go build -trimpath -ldflags='-s -w' -o nx-wings .

        chmod +x nx-wings

        success "NX-WINGS build completed."
    else
        error "Go could not be installed."
    fi

    echo
    echo -e "${CYAN}Wings directory:${NC} $WINGS_DIR"

    pause_screen
}

# ---------------- CLOUDFLARE ----------------

cloudflare() {

    header

    echo -e "${WHITE}  CLOUDFLARE${NC}"
    echo -e "${GRAY}  ─────────────────────────────────────────────${NC}"
    echo

    info "Starting NyroxHub Cloudflare manager..."
    echo

    if command_exists curl; then
        bash <(curl -fsSL "$CLOUDFLARE_SCRIPT")
    else
        error "curl is not installed."
        pause_screen
    fi
}

# ---------------- UNINSTALL PANEL ----------------

uninstall_panel() {

    header

    echo -e "${RED}  UNINSTALL NX PANEL${NC}"
    echo
    echo -e "${YELLOW}  WARNING:${NC}"
    echo "  This removes the NX Panel installation."
    echo

    read -rp "  Type DELETE to continue: " confirm

    if [[ "$confirm" != "DELETE" ]]; then
        info "Cancelled."
        pause_screen
        return
    fi

    if [[ -d "$PANEL_DIR" ]]; then
        rm -rf "$PANEL_DIR"
        success "NX Panel files removed."
    else
        info "NX Panel directory does not exist."
    fi

    pause_screen
}

# ---------------- UNINSTALL WINGS ----------------

uninstall_wings() {

    header

    echo -e "${RED}  UNINSTALL NX WINGS${NC}"
    echo
    echo -e "${YELLOW}  WARNING:${NC}"
    echo "  This removes the NX-WINGS installation."
    echo "  Docker containers/data are NOT automatically deleted."
    echo

    read -rp "  Type DELETE to continue: " confirm

    if [[ "$confirm" != "DELETE" ]]; then
        info "Cancelled."
        pause_screen
        return
    fi

    if [[ -d "$WINGS_DIR" ]]; then
        rm -rf "$WINGS_DIR"
        success "NX-WINGS files removed."
    else
        info "NX-WINGS directory does not exist."
    fi

    pause_screen
}

# ---------------- STATUS ----------------

status_line() {

    local panel_status="${RED}OFFLINE${NC}"
    local wings_status="${RED}OFFLINE${NC}"
    local nginx_status="${RED}OFFLINE${NC}"

    if [[ -d "$PANEL_DIR" ]]; then
        panel_status="${GREEN}INSTALLED${NC}"
    fi

    if [[ -d "$WINGS_DIR" ]]; then
        wings_status="${GREEN}INSTALLED${NC}"
    fi

    if command_exists nginx; then
        if systemctl is-active --quiet nginx 2>/dev/null; then
            nginx_status="${GREEN}RUNNING${NC}"
        else
            nginx_status="${YELLOW}INSTALLED${NC}"
        fi
    fi

    echo -e "  ${GRAY}Panel :${NC}  $panel_status"
    echo -e "  ${GRAY}Wings :${NC}  $wings_status"
    echo -e "  ${GRAY}NGINX :${NC}  $nginx_status"
}

# ---------------- MENU ----------------

menu() {

    header

    echo -e "${CYAN}  SYSTEM STATUS${NC}"
    echo -e "${GRAY}  ─────────────────────────────────────────────${NC}"

    status_line

    echo
    echo -e "${WHITE}  MENU SECTION${NC}"
    echo -e "${GRAY}  ─────────────────────────────────────────────${NC}"
    echo

    echo -e "  ${GREEN}1)${NC} INSTALL NX PANEL"
    echo -e "  ${GREEN}2)${NC} INSTALL NX WINGS"
    echo -e "  ${BLUE}3)${NC} CLOUDFLARE ${GRAY}(MAKE YOUR HOSTING DOMAIN)${NC}"
    echo -e "  ${RED}4)${NC} UNINSTALL NX PANEL"
    echo -e "  ${RED}5)${NC} UNINSTALL NX WINGS"
    echo -e "  ${YELLOW}6)${NC} THEME ${GRAY}(SOON)${NC}"
    echo
    echo -e "  ${GRAY}0)${NC} EXIT"
    echo

    echo -ne "${PURPLE}  root@nx-dactyl:~# ${NC}"
    read -r choice

    case "$choice" in

        1)
            install_panel
            ;;

        2)
            install_wings
            ;;

        3)
            cloudflare
            ;;

        4)
            uninstall_panel
            ;;

        5)
            uninstall_wings
            ;;

        6)
            header
            echo -e "${YELLOW}  THEME SYSTEM${NC}"
            echo
            echo "  Theme customization is coming soon."
            echo
            pause_screen
            ;;

        0)
            clear
            echo
            echo -e "${PURPLE}  NX DACTYL${NC}"
            echo -e "${GRAY}  Session closed.${NC}"
            echo
            exit 0
            ;;

        *)
            error "Invalid option."
            sleep 1
            ;;
    esac
}

# ---------------- START ----------------

root_check

while true; do
    menu
done
