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
    echo -Bri "${BLUE}[DEBUG]${NC} $1" >&2
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
    }
    
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
        fail "Neither curl nor wget is available. Please install one of them."
    }
    
    chmod "$mode" "$dest" || fail "Failed to set permissions on $dest"
}

# Function to detect the OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME=$ID
    elif [ -f /etc/debian_version ]; then
        OS_NAME="debian"
    elif [ -f /etc/redhat-release ]; then
        OS_NAME="redhat"
    elif [[ "$(uname)" == "Darwin" ]]; then
        OS_NAME="darwin"
    else
        OS_NAME="unknown"
    fi
    echo "$OS_NAME"
}

# Function to detect package manager
get_pkg_manager() {
    local os=$1
    case $os in
        ubuntu|debian|pop|mint)
            echo "apt-get"
            ;;
        fedora|rhel|centos|rocky|almalinux)
            echo "dnf"
            ;;
        darwin)
            if command -v brew >/dev/null 2>&1; then
                echo "brew"
            else
                echo "none"
            fi
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Function to check if running in pipe mode
is_pipe_mode() {
    [ ! -t 0 ]
}

# Function to install kubectl based on OS
install_kubectl() {
    local os=$1
    local pkg_manager=$2
    
    echo -e "${YELLOW}Installing kubectl...${NC}"
    
    case $pkg_manager in
        apt-get)
            sudo apt-get update
            sudo apt-get install -y apt-transport-https ca-certificates curl
            curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg
            echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
            sudo apt-get update
            sudo apt-get install -y kubectl
            ;;
        dnf)
            cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
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
            echo -e "${YELLOW}Please install kubectl manually following the instructions at:${NC}"
            echo "https://kubernetes.io/docs/tasks/tools/install-kubectl/"
            if ! is_pipe_mode; then
                read -p "Press Enter to continue with the script installation, or Ctrl+C to abort..."
            fi
            ;;
    esac
}

# Check if kubectl is installed and offer installation if missing
check_and_install_kubectl() {
    if ! command -v kubectl >/dev/null 2>&1; then
        echo -e "${YELLOW}kubectl not found!${NC}"
        local os=$(detect_os)
        local pkg_manager=$(get_pkg_manager "$os")
        
        if ! is_pipe_mode; then
            read -p "Would you like to install kubectl? [Y/n] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
                install_kubectl "$os" "$pkg_manager"
            fi
        else
            # In pipe mode, automatically install if we have a supported package manager
            if [ "$pkg_manager" != "unknown" ] && [ "$pkg_manager" != "none" ]; then
                install_kubectl "$os" "$pkg_manager"
            else
                echo -e "${YELLOW}Skipping kubectl installation in pipe mode for unsupported system${NC}"
            fi
        fi
    else
        echo -e "${GREEN}✓ kubectl is already installed${NC}"
    fi
}

# Ensure ~/.local/bin is in PATH
ensure_local_bin_in_path() {
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
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

# Install the script
install_script() {
    safe_mkdir "$USER_BIN" 755
    
    # If the script is being piped in, read from stdin
    if ! is_pipe_mode; then
        echo -e "${GREEN}Downloading $INSTALL_NAME...${NC}"
        download_file "${BASE_URL}/${SCRIPT_NAME}" "$USER_BIN/$INSTALL_NAME" 755
    else
        echo -e "${GREEN}Installing $INSTALL_NAME from pipe...${NC}"
        cat > "$USER_BIN/$INSTALL_NAME" || fail "Failed to write script to $USER_BIN/$INSTALL_NAME"
        chmod +x "$USER_BIN/$INSTALL_NAME" || fail "Failed to set executable permissions"
    fi

    # Verify installation
    if [ -x "$USER_BIN/$INSTALL_NAME" ]; then
        echo -e "${GREEN}✓ Installation successful!${NC}"
        echo -e "The script has been installed to: $USER_BIN/$INSTALL_NAME"
        echo -e "\nTo use the script, run: $INSTALL_NAME [command] [options]"
        echo -e "For help, run: $INSTALL_NAME help"
        
        # Notify about PATH if it was just added
        if [[ ":$PATH:" != *":$USER_BIN:"* ]]; then
            echo -e "\n${GREEN}NOTE:${NC} Please restart your shell or run:"
            if [ -f "$HOME/.zshrc" ]; then
                echo -e "source ~/.zshrc"
            elif [ -f "$HOME/.bashrc" ]; then
                echo -e "source ~/.bashrc"
            elif [ -f "$HOME/.profile" ]; then
                echo -e "source ~/.profile"
            fi
        fi
    else
        fail "Installation failed"
    fi
}

main() {
    echo -e "${GREEN}Starting installation...${NC}"
    
    safe_mkdir "$USER_BIN" 755
    ensure_local_bin_in_path
    check_and_install_kubectl
    install_script
    
    echo -e "${GREEN}Installation complete!${NC}"
}

# Pipe-to-bash handling with proper variable passing
if [ ! -t 0 ]; then
    exec bash -c "$(declare -f debug_log fail safe_mkdir download_file detect_os get_pkg_manager \
                   is_pipe_mode install_kubectl check_and_install_kubectl ensure_local_bin_in_path \
                   install_script main); \
                   USER_BIN=\"$USER_BIN\" SCRIPT_NAME=\"$SCRIPT_NAME\" \
                   INSTALL_NAME=\"$INSTALL_NAME\" REPO_OWNER=\"$REPO_OWNER\" \
                   REPO_NAME=\"$REPO_NAME\" REPO_BRANCH=\"$REPO_BRANCH\" \
                   BASE_URL=\"$BASE_URL\" GREEN=\"$GREEN\" YELLOW=\"$YELLOW\" \
                   RED=\"$RED\" BLUE=\"$BLUE\" NC=\"$NC\" main"
else
    main
fi
