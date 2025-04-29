#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# System paths
USER_BIN="$HOME/.local/bin"
SCRIPT_NAME="manage_k8s.sh"
INSTALL_NAME="k8s-manager"
REPO_OWNER="lpolish"
REPO_NAME="manage-k8s"
REPO_BRANCH="master"
BASE_URL="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${REPO_BRANCH}"

# Debug logging
debug_log() {
    echo -e "${BLUE}[DEBUG]${NC} $1" >&2
}

# Error handling
fail() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

# Safe directory creation
safe_mkdir() {
    local dir="$1"
    local mode="${2:-755}"
    if [ -z "$dir" ]; then
        fail "Directory path is empty"
    fi
    debug_log "Creating directory: $dir"
    mkdir -p "$dir" || fail "Failed to create directory: $dir"
    chmod "$mode" "$dir" || fail "Failed to set permissions on: $dir"
}

# Download file from GitHub
download_file() {
    local url="$1"
    local dest="$2"
    local mode="${3:-644}"
    debug_log "Downloading $url to $dest"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$dest" || fail "Failed to download $url"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$url" -O "$dest" || fail "Failed to download $url"
    else
        fail "Neither curl nor wget is available. Please install one."
    fi
    chmod "$mode" "$dest" || fail "Failed to set permissions on $dest"
}

# Detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    elif [ -f /etc/redhat-release ]; then
        echo "redhat"
    elif [[ "$(uname)" == "Darwin" ]]; then
        echo "darwin"
    else
        echo "unknown"
    fi
}

# Detect package manager
get_pkg_manager() {
    local os="$1"
    case "$os" in
        debian|ubuntu)
            echo "apt-get"
            ;;
        redhat|centos|fedora)
            echo "dnf"
            ;;
        darwin)
            echo "brew"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Install kubectl
install_kubectl() {
    local os="$1"
    local pkg_manager="$2"
    echo -e "${YELLOW}Installing kubectl...${NC}"

    case "$pkg_manager" in
        apt-get)
            sudo apt-get update
            sudo apt-get install -y apt-transport-https ca-certificates curl
            sudo mkdir -p /etc/apt/keyrings
            curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg
            echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
            sudo apt-get update
            sudo apt-get install -y kubectl
            ;;
        dnf)
            sudo tee /etc/yum.repos.d/kubernetes.repo <<EOF
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
            sudo dnf install -y kubectl
            ;;
        brew)
            brew install kubectl
            ;;
        *)
            echo -e "${YELLOW}Please install kubectl manually:${NC}"
            echo "https://kubernetes.io/docs/tasks/tools/install-kubectl/"
            ;;
    esac
}

# Check if kubectl is installed and install if missing
check_and_install_kubectl() {
    if ! command -v kubectl >/dev/null 2>&1; then
        echo -e "${YELLOW}kubectl not found!${NC}"
        local os=$(detect_os)
        local pkg_manager=$(get_pkg_manager "$os")

        if ! is_pipe_mode; then
            read -p "Install kubectl now? [Y/n] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
                install_kubectl "$os" "$pkg_manager"
            fi
        else
            echo -e "${GREEN}Installing $INSTALL_NAME via piped installer...${NC}"
            safe_mkdir "$USER_BIN" 755
            download_file "${BASE_URL}/${SCRIPT_NAME}" "$USER_BIN/$INSTALL_NAME" 755
        
            echo -e "${GREEN}✓ $INSTALL_NAME installed successfully at $USER_BIN/$INSTALL_NAME${NC}"
        
            # Ensure PATH is correctly set
            ensure_local_bin_in_path
        
            echo -e "\nYou can now run: $INSTALL_NAME [command] [options]"
            exit 0
        fi
    else
        echo -e "${GREEN}✓ kubectl already installed${NC}"
    fi
}

# Check for pipe-to-bash mode
is_pipe_mode() {
    [ ! -t 0 ]
}

# Ensure ~/.local/bin is in PATH
ensure_local_bin_in_path() {
    if [[ ":$PATH:" != *":$USER_BIN:"* ]]; then
        debug_log "Adding $USER_BIN to PATH"
        SHELL_FILE=""
        if [ -f "$HOME/.zshrc" ]; then
            SHELL_FILE="$HOME/.zshrc"
        elif [ -f "$HOME/.bashrc" ]; then
            SHELL_FILE="$HOME/.bashrc"
        elif [ -f "$HOME/.profile" ]; then
            SHELL_FILE="$HOME/.profile"
        fi
        if [ -n "$SHELL_FILE" ]; then
            echo "export PATH=\"\$PATH:$USER_BIN\"" >> "$SHELL_FILE"
            export PATH="$USER_BIN:$PATH"
        fi
    fi
}

# Install manage_k8s script
install_script() {
    safe_mkdir "$USER_BIN" 755
    if ! is_pipe_mode; then
        echo -e "${GREEN}Downloading $INSTALL_NAME...${NC}"
        download_file "${BASE_URL}/${SCRIPT_NAME}" "$USER_BIN/$INSTALL_NAME" 755
    else
        echo -e "${GREEN}Installing $INSTALL_NAME from pipe...${NC}"
        cat > "$USER_BIN/$INSTALL_NAME" || fail "Failed to write to $USER_BIN/$INSTALL_NAME"
        chmod +x "$USER_BIN/$INSTALL_NAME" || fail "Failed to set executable permissions"
    fi

    if [ -x "$USER_BIN/$INSTALL_NAME" ]; then
        echo -e "${GREEN}✓ Installation successful!${NC}"
        echo -e "Installed at: $USER_BIN/$INSTALL_NAME"
        echo -e "Run: $INSTALL_NAME [command] [options]"
        echo -e "For help: $INSTALL_NAME help"
        if [[ ":$PATH:" != *":$USER_BIN:"* ]]; then
            echo -e "\n${GREEN}NOTE:${NC} Restart your shell or run:"
            if [ -f "$HOME/.zshrc" ]; then
                echo "source ~/.zshrc"
            elif [ -f "$HOME/.bashrc" ]; then
                echo "source ~/.bashrc"
            elif [ -f "$HOME/.profile" ]; then
                echo "source ~/.profile"
            fi
        fi
    else
        fail "Installation failed"
    fi
}

# Main install workflow
main() {
    echo -e "${GREEN}Starting installation...${NC}"
    safe_mkdir "$USER_BIN" 755
    ensure_local_bin_in_path
    check_and_install_kubectl
    install_script
    echo -e "${GREEN}Installation complete!${NC}"
}

# Pipe-to-bash handling
if is_pipe_mode; then
    TEMP_SCRIPT=$(mktemp) || fail "Failed to create temporary file"
    debug_log "Writing script to temp file: $TEMP_SCRIPT"
    cat > "$TEMP_SCRIPT" || fail "Failed to write to temporary file"
    chmod +x "$TEMP_SCRIPT" || fail "Failed to make temporary file executable"
    bash "$TEMP_SCRIPT" || fail "Failed to execute temporary script"
    rm -f "$TEMP_SCRIPT"
else
    main
fi
