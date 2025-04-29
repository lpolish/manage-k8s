#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Determine user's home bin directory
USER_BIN="$HOME/.local/bin"
SCRIPT_NAME="manage_k8s.sh"
INSTALL_NAME="k8s-manager"

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

# Create user bin directory if it doesn't exist
if [ ! -d "$USER_BIN" ]; then
    mkdir -p "$USER_BIN"
fi

# Add USER_BIN to PATH if not already present
if [[ ":$PATH:" != *":$USER_BIN:"* ]]; then
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
    fi
fi

# Check and install kubectl if needed
check_and_install_kubectl

# Download and install the script
install_script() {
    # If the script is being piped in, read from stdin
    if ! is_pipe_mode; then
        echo -e "${GREEN}Downloading $INSTALL_NAME...${NC}"
        curl -fsSL "https://raw.githubusercontent.com/yourusername/k8s-manager/main/$SCRIPT_NAME" > "$USER_BIN/$INSTALL_NAME"
    else
        echo -e "${GREEN}Installing $INSTALL_NAME from pipe...${NC}"
        cat > "$USER_BIN/$INSTALL_NAME"
    fi

    # Make the script executable
    chmod +x "$USER_BIN/$INSTALL_NAME"

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
        echo -e "${RED}✗ Installation failed${NC}"
        exit 1
    fi
}

install_script