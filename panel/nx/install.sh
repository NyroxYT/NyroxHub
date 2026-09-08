#!/usr/bin/env bash
# ============================================================
#                 NX DACTYL v2
#              REAL PRODUCTION INSTALLER
# ============================================================
#
#  NX Panel  -> NGINX :443 -> NX Panel :8080
#  NX-WINGS  -> Docker
#  Cloudflare Tunnel -> HTTPS localhost:443
#
#  Install:
#      chmod +x NX.sh
#      sudo ./NX.sh
#
# ============================================================

set -Eeuo pipefail

# ============================================================
# COLORS
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'

# ============================================================
# PATHS
# ============================================================

PANEL_DIR="/var/www/NX"
WINGS_DIR="/var/www/NX-WINGS"
DASH_DIR="/var/www/NX-DASH"

PANEL_STORAGE="${PANEL_DIR}/storage"
WINGS_DATA="/var/lib/nx-wings/servers"

NGINX_CONF="/etc/nginx/sites-available/nx-panel"
NGINX_LINK="/etc/nginx/sites-enabled/nx-panel"

PANEL_SERVICE="nx-panel"
WINGS_SERVICE="nx-wings"

# ============================================================
# PORTS
# ============================================================

PANEL_PORT="8080"
WINGS_PORT="8080"
HTTPS_PORT="443"

# ============================================================
# REPOSITORIES
# ============================================================

PANEL_REPO="https://github.com/NyroxYT/NX.git"
WINGS_REPO="https://github.com/NyroxYT/NX-WINGS.git"
DASH_REPO="https://github.com/NyroxYT/NX-DASH.git"

# ============================================================
# CLOUDFLARE SCRIPT
# ============================================================

CLOUDFLARE_SCRIPT="https://raw.githubusercontent.com/NyroxYT/NyroxHub/refs/heads/main/toolbox/cloudflare.sh"

# ============================================================
# SOFTWARE VERSIONS
# ============================================================

NODE_MAJOR="20"
GO_VERSION="1.23.12"

# ============================================================
# GLOBAL VARIABLES
# ============================================================

PANEL_DOMAIN=""
INSTALL_MODE=""
BACKUP_DIR=""

# ============================================================
# LOGGING
# ============================================================

info() {
    echo -e "  ${CYAN}[INFO]${NC} $1"
}

success() {
    echo -e "  ${GREEN}[✓]${NC} $1"
}

warning() {
    echo -e "  ${YELLOW}[!]${NC} $1"
}

error() {
    echo -e "  ${RED}[✗]${NC} $1"
}

section() {
    echo
    echo -e "${PURPLE}============================================================${NC}"
    echo -e "${WHITE}  $1${NC}"
    echo -e "${PURPLE}============================================================${NC}"
    echo
}

die() {
    error "$1"
    exit 1
}

# ============================================================
# BANNER
# ============================================================

banner() {
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

    echo -e "${CYAN}                    [ NX DACTYL v2 ]${NC}"
    echo -e "${GRAY}                 REAL PRODUCTION INSTALLER${NC}"
    echo
}

# ============================================================
# ROOT CHECK
# ============================================================

check_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        error "This installer must run as root."
        echo
        echo "Run:"
        echo
        echo "  sudo ./NX.sh"
        echo
        exit 1
    fi
}

# ============================================================
# OS DETECTION
# ============================================================

detect_os() {
    if [[ ! -f /etc/os-release ]]; then
        die "Cannot detect operating system."
    fi

    source /etc/os-release

    OS_ID="${ID:-unknown}"
    OS_VERSION="${VERSION_ID:-unknown}"

    info "Detected OS: ${OS_ID} ${OS_VERSION}"

    case "$OS_ID" in
        ubuntu)
            success "Ubuntu detected."
            ;;
        debian)
            success "Debian detected."
            ;;
        *)
            warning "This installer is primarily designed for Ubuntu/Debian."
            echo
            read -rp "Continue anyway? [y/N]: " answer

            if [[ ! "$answer" =~ ^[Yy]$ ]]; then
                exit 0
            fi
            ;;
    esac
}

# ============================================================
# COMMAND CHECK
# ============================================================

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# ============================================================
# DOMAIN VALIDATION
# ============================================================

valid_domain() {
    local domain="$1"

    [[ "$domain" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,63}$ ]]
}

# ============================================================
# DOMAIN INPUT
# ============================================================

ask_domain() {
    section "PANEL DOMAIN"

    echo "  Enter the real domain you want to use for NX Panel."
    echo
    echo "  Example:"
    echo
    echo "    panel.example.com"
    echo
    echo "  Do NOT enter:"
    echo
    echo "    https://panel.example.com"
    echo "    panel.example.com/"
    echo

    while true; do
        read -rp "  Panel domain: " PANEL_DOMAIN

        PANEL_DOMAIN="${PANEL_DOMAIN#https://}"
        PANEL_DOMAIN="${PANEL_DOMAIN#http://}"
        PANEL_DOMAIN="${PANEL_DOMAIN%/}"

        if valid_domain "$PANEL_DOMAIN"; then
            break
        fi

        error "Invalid domain."
        echo
    done

    echo
    success "Panel domain: ${PANEL_DOMAIN}"
}

# ============================================================
# PACKAGE MANAGER
# ============================================================

detect_package_manager() {
    if command_exists apt-get; then
        PACKAGE_MANAGER="apt"
    elif command_exists dnf; then
        PACKAGE_MANAGER="dnf"
    elif command_exists yum; then
        PACKAGE_MANAGER="yum"
    else
        die "No supported package manager found."
    fi
}

# ============================================================
# BASE PACKAGES
# ============================================================

install_base_packages() {
    section "BASE DEPENDENCIES"

    case "$PACKAGE_MANAGER" in

        apt)
            export DEBIAN_FRONTEND=noninteractive

            apt-get update -y

            apt-get install -y \
                ca-certificates \
                curl \
                wget \
                git \
                openssl \
                nginx \
                build-essential \
                unzip \
                tar \
                jq \
                gnupg \
                lsb-release \
                software-properties-common \
                apt-transport-https
            ;;

        dnf)
            dnf install -y \
                ca-certificates \
                curl \
                wget \
                git \
                openssl \
                nginx \
                gcc \
                gcc-c++ \
                make \
                unzip \
                tar \
                jq
            ;;

        yum)
            yum install -y \
                ca-certificates \
                curl \
                wget \
                git \
                openssl \
                nginx \
                gcc \
                gcc-c++ \
                make \
                unzip \
                tar \
                jq
            ;;
    esac

    success "Base packages installed."
}

# ============================================================
# NODE.JS
# ============================================================

install_node() {
    section "NODE.JS"

    if command_exists node; then

        local major

        major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"

        if (( major >= NODE_MAJOR )); then
            success "Node.js $(node -v) already installed."
            success "npm $(npm -v)"
            return
        fi
    fi

    info "Installing Node.js ${NODE_MAJOR}.x..."

    case "$PACKAGE_MANAGER" in

        apt)
            curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash -
            apt-get install -y nodejs
            ;;

        dnf)
            curl -fsSL "https://rpm.nodesource.com/setup_${NODE_MAJOR}.x" | bash -
            dnf install -y nodejs
            ;;

        yum)
            curl -fsSL "https://rpm.nodesource.com/setup_${NODE_MAJOR}.x" | bash -
            yum install -y nodejs
            ;;
    esac

    command_exists node || die "Node.js installation failed."
    command_exists npm || die "npm installation failed."

    success "Node.js $(node -v)"
    success "npm $(npm -v)"
}

# ============================================================
# GO
# ============================================================

install_go() {
    section "GO"

    if command_exists go; then

        local current

        current="$(go version | awk '{print $3}' | sed 's/^go//')"

        if [[ "$(printf '%s\n' "$GO_VERSION" "$current" | sort -V | head -n1)" == "$GO_VERSION" ]]; then
            success "Go $(go version | awk '{print $3}') already installed."
            return
        fi
    fi

    info "Installing Go ${GO_VERSION}..."

    local architecture

    case "$(uname -m)" in

        x86_64)
            architecture="amd64"
            ;;

        aarch64)
            architecture="arm64"
            ;;

        arm64)
            architecture="arm64"
            ;;

        *)
            die "Unsupported CPU architecture: $(uname -m)"
            ;;
    esac

    rm -rf /usr/local/go

    curl -fsSL \
        "https://go.dev/dl/go${GO_VERSION}.linux-${architecture}.tar.gz" \
        -o /tmp/nx-go.tar.gz

    tar -C /usr/local -xzf /tmp/nx-go.tar.gz

    rm -f /tmp/nx-go.tar.gz

    cat >/etc/profile.d/nx-go.sh <<'EOF'
export PATH="/usr/local/go/bin:$PATH"
EOF

    export PATH="/usr/local/go/bin:$PATH"

    command_exists go || die "Go installation failed."

    success "$(go version)"
}

# ============================================================
# DOCKER
# ============================================================

install_docker() {
    section "DOCKER"

    if command_exists docker && systemctl is-active --quiet docker 2>/dev/null; then
        success "Docker is already running."
        docker --version
        return
    fi

    info "Installing Docker Engine..."

    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh

    sh /tmp/get-docker.sh

    rm -f /tmp/get-docker.sh

    systemctl enable docker
    systemctl start docker

    command_exists docker || die "Docker installation failed."

    if ! systemctl is-active --quiet docker; then
        die "Docker service failed to start."
    fi

    success "$(docker --version)"
}

# ============================================================
# DIRECTORIES
# ============================================================

prepare_directories() {
    section "DIRECTORIES"

    mkdir -p /var/www

    mkdir -p "$PANEL_DIR"

    mkdir -p "$PANEL_STORAGE"

    mkdir -p "$WINGS_DIR"

    mkdir -p "$WINGS_DATA"

    mkdir -p /etc/nginx/ssl

    success "Production directories prepared."
}

# ============================================================
# BACKUP
# ============================================================

backup_existing_panel() {
    if [[ -d "$PANEL_DIR" ]] && [[ -n "$(ls -A "$PANEL_DIR" 2>/dev/null || true)" ]]; then

        BACKUP_DIR="/var/backups/nx-panel-$(date +%Y%m%d-%H%M%S)"

        info "Existing NX Panel detected."
        info "Creating backup: ${BACKUP_DIR}"

        mkdir -p "$BACKUP_DIR"

        cp -a "$PANEL_DIR" "$BACKUP_DIR/"

        success "Panel backup created."
    fi
}

# ============================================================
# PANEL REPOSITORY
# ============================================================

install_panel_repository() {
    section "NX PANEL"

    if [[ -d "$PANEL_DIR/.git" ]]; then

        info "NX Panel repository already exists."

        git -C "$PANEL_DIR" fetch --all --prune

        git -C "$PANEL_DIR" pull --ff-only

        success "NX Panel repository updated."

    else

        if [[ -d "$PANEL_DIR" ]]; then

            if [[ -n "$(ls -A "$PANEL_DIR" 2>/dev/null || true)" ]]; then

                local old_dir

                old_dir="${PANEL_DIR}.old.$(date +%s)"

                mv "$PANEL_DIR" "$old_dir"

                mkdir -p "$PANEL_DIR"

                warning "Existing directory moved to ${old_dir}"
            fi
        fi

        info "Cloning NX Panel..."

        git clone "$PANEL_REPO" "$PANEL_DIR"

        success "NX Panel repository cloned."
    fi
}

# ============================================================
# PANEL NPM
# ============================================================

install_panel_dependencies() {
    section "NX PANEL NPM DEPENDENCIES"

    cd "$PANEL_DIR"

    if [[ ! -f package.json ]]; then
        die "NX Panel package.json was not found."
    fi

    if [[ -f package-lock.json ]]; then

        info "Running npm ci..."

        npm ci --omit=dev

    else

        info "Running npm install..."

        npm install --omit=dev

    fi

    success "NX Panel dependencies installed."
}

# ============================================================
# RANDOM SECRET
# ============================================================

generate_secret() {
    openssl rand -hex 64
}

# ============================================================
# PANEL ENV
# ============================================================

create_panel_env() {
    section "NX PANEL CONFIGURATION"

    local env_file="${PANEL_DIR}/.env"

    if [[ -f "$env_file" ]]; then

        warning "Existing .env found."

        echo
        echo "  Existing configuration will be preserved."
        echo

        return
    fi

    local jwt_secret

    jwt_secret="$(generate_secret)"

    local admin_email
    local admin_username
    local admin_password

    read -rp "  Admin email [admin@example.com]: " admin_email

    admin_email="${admin_email:-admin@example.com}"

    read -rp "  Admin username [admin]: " admin_username

    admin_username="${admin_username:-admin}"

    while true; do

        read -rsp "  Admin password: " admin_password

        echo

        if [[ -n "$admin_password" ]]; then
            break
        fi

        error "Password cannot be empty."

    done

    cat >"$env_file" <<EOF
NODE_ENV=production
PORT=${PANEL_PORT}

JWT_SECRET=${jwt_secret}

DATA_DIR=${PANEL_STORAGE}

NX_ADMIN_EMAIL=${admin_email}
NX_ADMIN_USERNAME=${admin_username}
NX_ADMIN_PASSWORD=${admin_password}

NX_SUPPORT_EMAIL=support@nxdactyl.local

NX_DASH_URL=https://dash.${PANEL_DOMAIN}
EOF

    chmod 600 "$env_file"

    success "Production .env created."
}

# ============================================================
# PANEL SYSTEMD SERVICE
# ============================================================

create_panel_service() {
    section "NX PANEL SERVICE"

    cat >"/etc/systemd/system/${PANEL_SERVICE}.service" <<EOF
[Unit]
Description=NX Dactyl Panel
Documentation=https://${PANEL_DOMAIN}
After=network.target

[Service]
Type=simple

WorkingDirectory=${PANEL_DIR}

EnvironmentFile=${PANEL_DIR}/.env

ExecStart=/usr/bin/npm start

Restart=always
RestartSec=5

User=root
Group=root

LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload

    systemctl enable "$PANEL_SERVICE"

    success "NX Panel systemd service created."
}

# ============================================================
# START PANEL
# ============================================================

start_panel() {
    section "STARTING NX PANEL"

    systemctl restart "$PANEL_SERVICE"

    sleep 3

    if systemctl is-active --quiet "$PANEL_SERVICE"; then

        success "NX Panel is RUNNING."

    else

        error "NX Panel failed to start."

        echo
        journalctl -u "$PANEL_SERVICE" --no-pager -n 50

        return 1
    fi
}

# ============================================================
# TLS CERTIFICATE
# ============================================================

create_tls_certificate() {
    section "LOCAL HTTPS CERTIFICATE"

    local cert="/etc/nginx/ssl/nx-panel.crt"
    local key="/etc/nginx/ssl/nx-panel.key"

    if [[ -f "$cert" && -f "$key" ]]; then

        warning "NX TLS certificate already exists."

        return
    fi

    info "Generating self-signed origin certificate..."

    openssl req \
        -x509 \
        -nodes \
        -newkey rsa:2048 \
        -keyout "$key" \
        -out "$cert" \
        -days 825 \
        -subj "/CN=${PANEL_DOMAIN}" \
        >/dev/null 2>&1

    chmod 600 "$key"

    success "Origin TLS certificate created."
}

# ============================================================
# NGINX CONFIG
# ============================================================

create_nginx_config() {
    section "NGINX"

    cat >"$NGINX_CONF" <<EOF
server {
    listen ${HTTPS_PORT} ssl;
    listen [::]:${HTTPS_PORT} ssl;

    server_name ${PANEL_DOMAIN};

    ssl_certificate /etc/nginx/ssl/nx-panel.crt;
    ssl_certificate_key /etc/nginx/ssl/nx-panel.key;

    ssl_protocols TLSv1.2 TLSv1.3;

    client_max_body_size 100M;

    proxy_buffering off;

    location / {
        proxy_pass http://127.0.0.1:${PANEL_PORT};

        proxy_http_version 1.1;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;

        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;

        proxy_set_header X-Forwarded-Proto https;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_read_timeout 3600;
        proxy_send_timeout 3600;
    }
}
EOF

    mkdir -p /etc/nginx/sites-enabled

    rm -f /etc/nginx/sites-enabled/default

    ln -sf "$NGINX_CONF" "$NGINX_LINK"

    nginx -t

    systemctl enable nginx

    systemctl restart nginx

    if systemctl is-active --quiet nginx; then

        success "NGINX is RUNNING."

    else

        die "NGINX failed to start."
    fi
}

# ============================================================
# FIREWALL
# ============================================================

configure_firewall() {
    section "FIREWALL"

    if command_exists ufw; then

        info "Configuring UFW..."

        ufw allow 22/tcp >/dev/null 2>&1 || true

        ufw allow 80/tcp >/dev/null 2>&1 || true

        ufw allow 443/tcp >/dev/null 2>&1 || true

        warning "UFW rules updated."

    else

        info "UFW is not installed. Skipping firewall configuration."
    fi
}

# ============================================================
# WINGS REPOSITORY
# ============================================================

install_wings_repository() {
    section "NX-WINGS"

    if [[ -d "$WINGS_DIR/.git" ]]; then

        info "NX-WINGS repository already exists."

        git -C "$WINGS_DIR" fetch --all --prune

        git -C "$WINGS_DIR" pull --ff-only

        success "NX-WINGS repository updated."

    else

        if [[ -d "$WINGS_DIR" ]]; then

            if [[ -n "$(ls -A "$WINGS_DIR" 2>/dev/null || true)" ]]; then

                local old_dir

                old_dir="${WINGS_DIR}.old.$(date +%s)"

                mv "$WINGS_DIR" "$old_dir"

                mkdir -p "$WINGS_DIR"

                warning "Existing Wings directory moved to ${old_dir}"
            fi
        fi

        info "Cloning NX-WINGS..."

        git clone "$WINGS_REPO" "$WINGS_DIR"

        success "NX-WINGS repository cloned."
    fi
}

# ============================================================
# WINGS BUILD
# ============================================================

build_wings() {
    section "BUILD NX-WINGS"

    cd "$WINGS_DIR"

    export PATH="/usr/local/go/bin:$PATH"

    command_exists go || die "Go is not installed."

    if [[ ! -f go.mod ]]; then
        die "NX-WINGS go.mod was not found."
    fi

    info "Downloading Go modules..."

    go mod download

    info "Building NX-WINGS..."

    go build \
        -trimpath \
        -ldflags="-s -w" \
        -o nx-wings \
        .

    chmod +x nx-wings

    success "NX-WINGS binary built."
}

# ============================================================
# WINGS TOKEN
# ============================================================

generate_wings_token() {
    openssl rand -hex 48
}

# ============================================================
# WINGS ENV
# ============================================================

create_wings_env() {
    section "NX-WINGS CONFIGURATION"

    local env_file="${WINGS_DIR}/.env"

    local token=""

    if [[ -f "$env_file" ]]; then

        token="$(grep '^NX_WINGS_TOKEN=' "$env_file" | cut -d= -f2- || true)"

    fi

    if [[ -z "$token" ]]; then

        token="nxnodeconf-$(generate_wings_token)"

    fi

    cat >"$env_file" <<EOF
NX_WINGS_ADDRESS=0.0.0.0:${WINGS_PORT}
NX_WINGS_TOKEN=${token}
NX_WINGS_DATA_DIR=${WINGS_DATA}
EOF

    chmod 600 "$env_file"

    echo
    echo -e "${YELLOW}  NX-WINGS NODE TOKEN${NC}"
    echo
    echo "  ${token}"
    echo
    warning "Save this token. You will need it when registering the node."
}

# ============================================================
# WINGS SERVICE
# ============================================================

create_wings_service() {
    section "NX-WINGS SERVICE"

    cat >"/etc/systemd/system/${WINGS_SERVICE}.service" <<EOF
[Unit]
Description=NX Dactyl Wings
Documentation=https://github.com/NyroxYT/NX-WINGS
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple

WorkingDirectory=${WINGS_DIR}

EnvironmentFile=${WINGS_DIR}/.env

ExecStart=${WINGS_DIR}/nx-wings

Restart=always
RestartSec=5

User=root
Group=root

LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload

    systemctl enable "$WINGS_SERVICE"

    success "NX-WINGS systemd service created."
}

# ============================================================
# START WINGS
# ============================================================

start_wings() {
    section "STARTING NX-WINGS"

    systemctl restart "$WINGS_SERVICE"

    sleep 3

    if systemctl is-active --quiet "$WINGS_SERVICE"; then

        success "NX-WINGS is RUNNING."

    else

        error "NX-WINGS failed to start."

        echo
        journalctl -u "$WINGS_SERVICE" --no-pager -n 50

        return 1
    fi
}

# ============================================================
# PANEL LOCAL HEALTH
# ============================================================

check_panel_health() {
    section "PANEL HEALTH CHECK"

    if curl -fsS \
        --max-time 10 \
        "http://127.0.0.1:${PANEL_PORT}/api/health" \
        >/dev/null 2>&1; then

        success "NX Panel API is responding."

    else

        warning "NX Panel health endpoint did not respond."

        echo
        echo "  Check:"
        echo
        echo "    journalctl -u ${PANEL_SERVICE} -f"
    fi
}

# ============================================================
# WINGS LOCAL HEALTH
# ============================================================

check_wings_health() {
    section "WINGS HEALTH CHECK"

    if curl -fsS \
        --max-time 10 \
        "http://127.0.0.1:${WINGS_PORT}/api/health" \
        >/dev/null 2>&1; then

        success "NX-WINGS API is responding."

    else

        warning "NX-WINGS health endpoint did not respond."

        echo
        echo "  Check:"
        echo
        echo "    journalctl -u ${WINGS_SERVICE} -f"
    fi
}

# ============================================================
# CLOUDFLARE MANAGER
# ============================================================

run_cloudflare_manager() {
    section "CLOUDFLARE"

    command_exists curl || die "curl is required."

    info "Launching NyroxHub Cloudflare manager..."

    echo

    bash <(curl -fsSL "$CLOUDFLARE_SCRIPT")
}

# ============================================================
# CLOUDFLARE INSTRUCTIONS
# ============================================================

show_cloudflare_configuration() {
    section "CLOUDFLARE TUNNEL SETTINGS"

    echo -e "  ${WHITE}Public hostname:${NC}"
    echo
    echo "    ${PANEL_DOMAIN}"
    echo
    echo -e "  ${WHITE}Service:${NC}"
    echo
    echo "    Type: HTTPS"
    echo "    URL: https://localhost:443"
    echo "    No TLS Verify: ON"
    echo

    echo -e "${GRAY}------------------------------------------------------------${NC}"

    echo
    echo "  Flow:"
    echo
    echo "    ${PANEL_DOMAIN}"
    echo "          ↓"
    echo "      Cloudflare"
    echo "          ↓"
    echo "     Cloudflare Tunnel"
    echo "          ↓"
    echo "     HTTPS localhost:443"
    echo "          ↓"
    echo "        NGINX"
    echo "          ↓"
    echo "     NX Panel :8080"
    echo
}

# ============================================================
# STATUS SERVICE
# ============================================================

service_status_line() {
    local service="$1"
    local label="$2"

    if systemctl is-active --quiet "$service" 2>/dev/null; then

        echo -e "  ${WHITE}${label}:${NC} ${GREEN}RUNNING${NC}"

    else

        echo -e "  ${WHITE}${label}:${NC} ${RED}STOPPED${NC}"
    fi
}

# ============================================================
# SYSTEM STATUS
# ============================================================

show_status() {
    banner

    section "SYSTEM STATUS"

    service_status_line "$PANEL_SERVICE" "NX PANEL"
    service_status_line "$WINGS_SERVICE" "NX-WINGS"
    service_status_line "nginx" "NGINX"
    service_status_line "docker" "DOCKER"

    echo

    if [[ -n "$PANEL_DOMAIN" ]]; then
        echo -e "  ${WHITE}Panel Domain:${NC} ${CYAN}${PANEL_DOMAIN}${NC}"
    fi

    echo

    pause_screen
}

# ============================================================
# PAUSE
# ============================================================

pause_screen() {
    echo
    read -rp "  Press ENTER to continue..."
}

# ============================================================
# PANEL UPDATE
# ============================================================

update_panel() {
    banner

    section "UPDATE NX PANEL"

    if [[ ! -d "$PANEL_DIR/.git" ]]; then

        error "NX Panel is not installed."

        pause_screen

        return
    fi

    git -C "$PANEL_DIR" fetch --all --prune

    git -C "$PANEL_DIR" pull --ff-only

    cd "$PANEL_DIR"

    if [[ -f package-lock.json ]]; then

        npm ci --omit=dev

    else

        npm install --omit=dev

    fi

    systemctl restart "$PANEL_SERVICE" 2>/dev/null || true

    success "NX Panel updated."

    pause_screen
}

# ============================================================
# WINGS UPDATE
# ============================================================

update_wings() {
    banner

    section "UPDATE NX-WINGS"

    if [[ ! -d "$WINGS_DIR/.git" ]]; then

        error "NX-WINGS is not installed."

        pause_screen

        return
    fi

    git -C "$WINGS_DIR" fetch --all --prune

    git -C "$WINGS_DIR" pull --ff-only

    cd "$WINGS_DIR"

    export PATH="/usr/local/go/bin:$PATH"

    go mod download

    go build \
        -trimpath \
        -ldflags="-s -w" \
        -o nx-wings \
        .

    chmod +x nx-wings

    systemctl restart "$WINGS_SERVICE" 2>/dev/null || true

    success "NX-WINGS updated."

    pause_screen
}

# ============================================================
# INSTALL DASH
# ============================================================

install_dash() {
    banner

    section "NX-DASH"

    mkdir -p /var/www

    if [[ -d "$DASH_DIR/.git" ]]; then

        info "NX-DASH already exists."

        git -C "$DASH_DIR" fetch --all --prune

        git -C "$DASH_DIR" pull --ff-only

    else

        if [[ -d "$DASH_DIR" ]]; then

            local old_dash

            old_dash="${DASH_DIR}.old.$(date +%s)"

            mv "$DASH_DIR" "$old_dash"

        fi

        git clone "$DASH_REPO" "$DASH_DIR"
    fi

    success "NX-DASH installed/updated."

    pause_screen
}

# ============================================================
# UNINSTALL PANEL
# ============================================================

uninstall_panel() {
    banner

    section "UNINSTALL NX PANEL"

    warning "This will remove:"
    echo
    echo "  ${PANEL_DIR}"
    echo "  ${PANEL_SERVICE} systemd service"
    echo "  NX Panel NGINX configuration"
    echo

    warning "Panel database/storage will be removed with the directory."
    echo

    read -rp "  Type DELETE to continue: " confirmation

    if [[ "$confirmation" != "DELETE" ]]; then

        warning "Cancelled."

        pause_screen

        return
    fi

    systemctl disable --now "$PANEL_SERVICE" 2>/dev/null || true

    rm -f "/etc/systemd/system/${PANEL_SERVICE}.service"

    rm -f "$NGINX_LINK"

    rm -f "$NGINX_CONF"

    systemctl daemon-reload

    if nginx -t >/dev/null 2>&1; then
        systemctl reload nginx || true
    fi

    rm -rf "$PANEL_DIR"

    success "NX Panel removed."

    pause_screen
}

# ============================================================
# UNINSTALL WINGS
# ============================================================

uninstall_wings() {
    banner

    section "UNINSTALL NX-WINGS"

    warning "This removes NX-WINGS itself."
    echo
    echo "  ${WINGS_DIR}"
    echo "  ${WINGS_SERVICE} systemd service"
    echo

    warning "Docker containers, images and server data will NOT be removed."
    echo

    read -rp "  Type DELETE to continue: " confirmation

    if [[ "$confirmation" != "DELETE" ]]; then

        warning "Cancelled."

        pause_screen

        return
    fi

    systemctl disable --now "$WINGS_SERVICE" 2>/dev/null || true

    rm -f "/etc/systemd/system/${WINGS_SERVICE}.service"

    systemctl daemon-reload

    rm -rf "$WINGS_DIR"

    success "NX-WINGS removed."

    pause_screen
}

# ============================================================
# SHOW LOGS
# ============================================================

show_panel_logs() {
    banner

    section "NX PANEL LOGS"

    journalctl -u "$PANEL_SERVICE" -n 100 --no-pager

    echo

    pause_screen
}

# ============================================================
# SHOW WINGS LOGS
# ============================================================

show_wings_logs() {
    banner

    section "NX-WINGS LOGS"

    journalctl -u "$WINGS_SERVICE" -n 100 --no-pager

    echo

    pause_screen
}

# ============================================================
# FULL INSTALL
# ============================================================

full_install() {
    banner

    section "NX DACTYL v2 INSTALLATION"

    ask_domain

    echo
    echo -e "  ${WHITE}Production installation:${NC}"
    echo
    echo "  Panel:"
    echo "    ${PANEL_DOMAIN}"
    echo
    echo "  Panel backend:"
    echo "    localhost:${PANEL_PORT}"
    echo
    echo "  HTTPS:"
    echo "    localhost:${HTTPS_PORT}"
    echo
    echo "  Wings:"
    echo "    0.0.0.0:${WINGS_PORT}"
    echo

    read -rp "  Start installation? [Y/n]: " confirmation

    if [[ "$confirmation" =~ ^[Nn]$ ]]; then
        warning "Installation cancelled."
        return
    fi

    # --------------------------------------------------------
    # STEP 1
    # --------------------------------------------------------

    section "[1/15] SYSTEM CHECK"

    check_root
    detect_os
    detect_package_manager

    success "System check complete."

    # --------------------------------------------------------
    # STEP 2
    # --------------------------------------------------------

    section "[2/15] BASE PACKAGES"

    install_base_packages

    # --------------------------------------------------------
    # STEP 3
    # --------------------------------------------------------

    section "[3/15] NODE.JS"

    install_node

    # --------------------------------------------------------
    # STEP 4
    # --------------------------------------------------------

    section "[4/15] GO"

    install_go

    # --------------------------------------------------------
    # STEP 5
    # --------------------------------------------------------

    section "[5/15] DOCKER"

    install_docker

    # --------------------------------------------------------
    # STEP 6
    # --------------------------------------------------------

    section "[6/15] DIRECTORIES"

    prepare_directories

    # --------------------------------------------------------
    # STEP 7
    # --------------------------------------------------------

    section "[7/15] PANEL REPOSITORY"

    backup_existing_panel

    install_panel_repository

    # --------------------------------------------------------
    # STEP 8
    # --------------------------------------------------------

    section "[8/15] PANEL DEPENDENCIES"

    install_panel_dependencies

    # --------------------------------------------------------
    # STEP 9
    # --------------------------------------------------------

    section "[9/15] PANEL ENVIRONMENT"

    create_panel_env

    # --------------------------------------------------------
    # STEP 10
    # --------------------------------------------------------

    section "[10/15] PANEL SERVICE"

    create_panel_service

    start_panel

    # --------------------------------------------------------
    # STEP 11
    # --------------------------------------------------------

    section "[11/15] NGINX"

    create_tls_certificate

    create_nginx_config

    configure_firewall

    # --------------------------------------------------------
    # STEP 12
    # --------------------------------------------------------

    section "[12/15] WINGS REPOSITORY"

    install_wings_repository

    build_wings

    # --------------------------------------------------------
    # STEP 13
    # --------------------------------------------------------

    section "[13/15] WINGS CONFIGURATION"

    create_wings_env

    create_wings_service

    start_wings

    # --------------------------------------------------------
    # STEP 14
    # --------------------------------------------------------

    section "[14/15] HEALTH CHECKS"

    check_panel_health

    check_wings_health

    # --------------------------------------------------------
    # STEP 15
    # --------------------------------------------------------

    section "[15/15] CLOUDFLARE"

    show_cloudflare_configuration

    # --------------------------------------------------------
    # COMPLETE
    # --------------------------------------------------------

    section "INSTALLATION COMPLETE"

    echo -e "${GREEN}"
    cat <<'EOF'
  ╔════════════════════════════════════════════════════════╗
  ║                                                        ║
  ║             NX DACTYL v2 INSTALLED                    ║
  ║                                                        ║
  ╚════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"

    echo
    echo -e "  ${WHITE}NX Panel:${NC}"
    echo
    echo "    https://${PANEL_DOMAIN}"
    echo

    echo -e "  ${WHITE}Cloudflare Tunnel:${NC}"
    echo
    echo "    Type: HTTPS"
    echo "    URL: https://localhost:443"
    echo "    No TLS Verify: ON"
    echo

    echo -e "  ${WHITE}Panel service:${NC}"
    echo
    echo "    systemctl status ${PANEL_SERVICE}"
    echo

    echo -e "  ${WHITE}Wings service:${NC}"
    echo
    echo "    systemctl status ${WINGS_SERVICE}"
    echo

    echo -e "  ${WHITE}Panel logs:${NC}"
    echo
    echo "    journalctl -u ${PANEL_SERVICE} -f"
    echo

    echo -e "  ${WHITE}Wings logs:${NC}"
    echo
    echo "    journalctl -u ${WINGS_SERVICE} -f"
    echo

    warning "Next step: configure your Cloudflare Tunnel using the settings above."

    echo

    read -rp "  Launch Cloudflare manager now? [y/N]: " cloudflare_answer

    if [[ "$cloudflare_answer" =~ ^[Yy]$ ]]; then
        run_cloudflare_manager
    fi

    pause_screen
}

# ============================================================
# QUICK DOMAIN INFO
# ============================================================

domain_info() {
    banner

    section "DOMAIN CONFIGURATION"

    if [[ -z "$PANEL_DOMAIN" ]]; then

        echo "  No domain loaded in this installer session."

        echo

        if [[ -f "${PANEL_DIR}/.env" ]]; then
            echo "  Panel .env exists."

            echo "  Run option 1 to configure the domain."
        fi

    else

        echo "  Panel domain:"
        echo
        echo "    ${PANEL_DOMAIN}"
        echo

        show_cloudflare_configuration
    fi

    pause_screen
}

# ============================================================
# MENU
# ============================================================

main_menu() {
    while true; do

        banner

        echo -e "${WHITE}  MENU SECTION${NC}"
        echo -e "${GRAY}  ─────────────────────────────────────────────${NC}"
        echo

        echo -e "  ${GREEN}1)${NC} INSTALL NX DACTYL"
        echo -e "     ${GRAY}Panel + Wings + Docker + NGINX${NC}"
        echo

        echo -e "  ${GREEN}2)${NC} INSTALL / UPDATE NX PANEL"
        echo

        echo -e "  ${GREEN}3)${NC} INSTALL / UPDATE NX WINGS"
        echo

        echo -e "  ${BLUE}4)${NC} CLOUDFLARE"
        echo -e "     ${GRAY}Make your hosting domain${NC}"
        echo

        echo -e "  ${CYAN}5)${NC} INSTALL / UPDATE NX-DASH"
        echo

        echo -e "  ${CYAN}6)${NC} SHOW DOMAIN / CLOUDFLARE SETTINGS"
        echo

        echo -e "  ${YELLOW}7)${NC} SYSTEM STATUS"
        echo

        echo -e "  ${YELLOW}8)${NC} NX PANEL LOGS"
        echo

        echo -e "  ${YELLOW}9)${NC} NX-WINGS LOGS"
        echo

        echo -e "  ${RED}10)${NC} UNINSTALL NX PANEL"
        echo

        echo -e "  ${RED}11)${NC} UNINSTALL NX WINGS"
        echo

        echo -e "  ${PURPLE}12)${NC} THEME ${GRAY}(SOON)${NC}"
        echo

        echo -e "  ${GRAY}0)${NC} EXIT"
        echo

        echo -ne "${PURPLE}  root@nx-dactyl:~# ${NC}"

        read -r choice

        case "$choice" in

            1)
                full_install
                ;;

            2)
                install_base_packages
                install_node
                update_panel
                ;;

            3)
                install_base_packages
                install_go
                install_docker
                update_wings
                ;;

            4)
                run_cloudflare_manager
                ;;

            5)
                install_dash
                ;;

            6)
                domain_info
                ;;

            7)
                show_status
                ;;

            8)
                show_panel_logs
                ;;

            9)
                show_wings_logs
                ;;

            10)
                uninstall_panel
                ;;

            11)
                uninstall_wings
                ;;

            12)
                banner

                section "THEME"

                echo "  Theme customization is coming soon."

                pause_screen
                ;;

            0)
                clear

                echo
                echo -e "${PURPLE}  NX DACTYL v2${NC}"
                echo -e "${GRAY}  Session closed.${NC}"
                echo

                exit 0
                ;;

            *)
                error "Invalid option."

                sleep 1
                ;;
        esac
    done
}

# ============================================================
# ERROR HANDLER
# ============================================================

installer_error() {
    local line="$1"

    echo
    error "NX DACTYL installer stopped."
    error "Error on line: ${line}"
    echo

    echo "Useful diagnostics:"
    echo
    echo "  systemctl status ${PANEL_SERVICE}"
    echo "  systemctl status ${WINGS_SERVICE}"
    echo "  systemctl status nginx"
    echo
    echo "  journalctl -u ${PANEL_SERVICE} -n 50"
    echo "  journalctl -u ${WINGS_SERVICE} -n 50"
    echo

    exit 1
}

trap 'installer_error "$LINENO"' ERR

# ============================================================
# START
# ============================================================

check_root
detect_os
detect_package_manager

main_menu
