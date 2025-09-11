#!/bin/bash

# Simple Neovim Deployment Script
# Copies local config and installs Neovim AppImage on remote machine

set -e

# Configuration
NVIM_APPIMAGE_URL="https://github.com/neovim/neovim/releases/download/v0.11.4/nvim-linux-x86_64.appimage"
LOCAL_CONFIG_DIR="$HOME/.config/nvim"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Get SSH connection string from user
get_ssh_connection() {
    echo "Please enter your SSH connection string (e.g., ssh -i ~/key.pem user@host):"
    read -r SSH_COMMAND

    if [[ -z "$SSH_COMMAND" ]]; then
        log_error "SSH connection string cannot be empty"
        exit 1
    fi

    # Extract the connection part (everything after 'ssh')
    SSH_ARGS="${SSH_COMMAND#ssh }"

    log_info "Using SSH connection: $SSH_COMMAND"
}

# Test SSH connection
test_connection() {
    log_info "Testing SSH connection..."

    if ssh $SSH_ARGS "echo 'Connection successful'" >/dev/null 2>&1; then
        log_success "✓ SSH connection working"
    else
        log_error "Cannot connect using: $SSH_COMMAND"
        exit 1
    fi
}

# Install Neovim AppImage
install_neovim() {
    log_info "Installing Neovim AppImage..."

    # Create .local/bin directory and download AppImage
    ssh $SSH_ARGS "
        mkdir -p ~/.local/bin
        curl -L '$NVIM_APPIMAGE_URL' -o ~/.local/bin/nvim
        chmod +x ~/.local/bin/nvim
    "

    # Add to PATH if not already there
    ssh $SSH_ARGS '
        if ! grep -q "\.local/bin" ~/.bashrc 2>/dev/null; then
            echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> ~/.bashrc
        fi
        if [[ -f ~/.zshrc ]] && ! grep -q "\.local/bin" ~/.zshrc 2>/dev/null; then
            echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> ~/.zshrc
        fi
    '

    log_success "✓ Neovim AppImage installed"
}

# Copy Neovim configuration
copy_config() {
    log_info "Copying Neovim configuration..."

    if [[ ! -d "$LOCAL_CONFIG_DIR" ]]; then
        log_error "Local config directory not found: $LOCAL_CONFIG_DIR"
        exit 1
    fi

    ssh $SSH_ARGS "mkdir -p ~/.config"

    # Properly split options vs destination
    SSH_DEST=$(echo "$SSH_ARGS" | grep -o '[^@[:space:]]*@[^[:space:]]*')
    SSH_OPTS=$(echo "$SSH_ARGS" | sed "s|$SSH_DEST||")

    rsync -avz --delete \
        -e "ssh $SSH_OPTS" \
        "$LOCAL_CONFIG_DIR/" \
        "$SSH_DEST:~/.config/nvim/"

    log_success "✓ Configuration copied"
}

# Test Neovim installation
test_neovim() {
    log_info "Testing Neovim installation..."

    if ssh $SSH_ARGS 'export PATH="$HOME/.local/bin:$PATH"; nvim --version' >/dev/null 2>&1; then
        log_success "✓ Neovim is working"
    else
        log_warning "⚠ Could not verify Neovim installation"
    fi
}

# Main execution
main() {
    echo "Nvim.sync script"
    echo "by Fabio Zahner"
    echo "=================================="
    echo

    get_ssh_connection
    test_connection
    install_neovim
    copy_config
    test_neovim

    echo
    log_success "Deployment complete!"
}

# Run the script
main
