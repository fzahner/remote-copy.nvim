#!/bin/bash

# Simple Neovim Deployment Script
# Copies local config and installs Neovim AppImage on remote machine
set -e

# Configuration
NVIM_APPIMAGE_URL="https://github.com/neovim/neovim/releases/download/stable/nvim-linux-x86_64.appimage"
LOCAL_CONFIG_DIR="$HOME/.config/nvim"
REMOTE_CONFIG_DIR="~/.config/nvim"

# Defaults
INSTALL_UTILS=true
INSTALL_GLOBAL=false

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

    if [[ "$INSTALL_GLOBAL" = true ]]; then
      log_info "Adding nvim to global PATH"
      ssh $SSH_ARGS '
        echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" | sudo tee /etc/profile.d/localbin.sh
        sudo chmod +x /etc/profile.d/localbin.sh
      '
    else
      log_info "Adding nvim to .bashrc/.zshrc"
      # Add to PATH if not already there
      ssh $SSH_ARGS '
          if ! grep -q "\.local/bin" ~/.bashrc 2>/dev/null; then
              echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> ~/.bashrc
          fi
          if [[ -f ~/.zshrc ]] && ! grep -q "\.local/bin" ~/.zshrc 2>/dev/null; then
              echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> ~/.zshrc
          fi
      '
    fi

    log_success "✓ Neovim AppImage installed"
}

# Copy Neovim configuration
copy_config() {
    log_info "Copying Neovim configuration..."

    if [[ ! -d "$LOCAL_CONFIG_DIR" ]]; then
        log_error "Local config directory not found: $LOCAL_CONFIG_DIR"
        exit 1
    fi

    ssh $SSH_ARGS "mkdir -p $REMOTE_CONFIG_DIR"

    # Properly split options vs destination
    SSH_DEST=$(echo "$SSH_ARGS" | grep -o '[^@[:space:]]*@[^[:space:]]*')
    SSH_OPTS=$(echo "$SSH_ARGS" | sed "s|$SSH_DEST||")

    rsync -avz --delete \
        -e "ssh $SSH_OPTS" \
        "$LOCAL_CONFIG_DIR/" \
        "$SSH_DEST:$REMOTE_CONFIG_DIR"

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

# Install packages needed for additional functionality
install_additional() {
  if [[ "$INSTALL_UTILS" = false ]]; then
    log_warning "Skipping installation of additional utils."
    return
  fi

  log_info "Installing additional utils..."
  if ! command -v ssh $SSH_ARGS "apt-get" &> /dev/null; then
    log_error "apt-get is not available. This script requires apt-get to install packages."
    exit 1
  fi

  log_info "- Installing xclip"
  ssh $SSH_ARGS "sudo apt-get update -qq"
  ssh $SSH_ARGS "sudo apt-get -qq -y install xclip > /dev/null"
  log_info "  - Adding xclip override to config"
  ssh $SSH_ARGS '
    echo >> ~/.config/nvim/init.lua &&
    echo "-- Add clipboard provider for remote session" >> ~/.config/nvim/init.lua &&
    echo "vim.g.clipboard = {
      name = \"xclip\",
      copy = {
        [\"+\"] = \"xclip -selection clipboard\",
        [\"*\"] = \"xclip -selection primary\",
      },
      paste = {
        [\"+\"] = \"xclip -selection clipboard -o\",
        [\"*\"] = \"xclip -selection primary -o\",
      },
      cache_enabled = 0
    }" >> ~/.config/nvim/init.lua
  '

  log_info "- Installing python3-venv"
  ssh $SSH_ARGS "sudo apt-get install python3-venv -qq > /dev/null"
  log_info "- Installing ripgrep"
  ssh $SSH_ARGS "sudo apt-get install ripgrep -qq > /dev/null"
  log_success "Installed additional utils."
}
show_help() {
    cat <<EOF
Usage: $(basename "$0") [options]

Script which copies local NeoVim configuration and installs the NeoVim Appimage on a remote, SSH-reachable machine.

This script (unless specified with --no-utils) also additionally installs:
  - xclip:        Used for copying into local register from remote nvim. Requires SSH session to be started with -X flag
  - python3-venv: Virtual environements are needed for vim functionality
  - rigrep:       Used for fuzzy finding (for example in telescope.nvim)

Options:
  --help              Show this help message
  --no-utils          Does not install additional utils (see above)
  --install-global    Adds nvim to the global path instead of the shell configuration file
  --appimage [URL]    Allows to specify the URL to the App Image. Default is $NVIM_APPIMAGE_URL

EOF
}


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
  install_additional

  echo
  log_success "Deployment complete!"
  echo
  log_info "Connect to the remote machine using:"
  echo "$SSH_COMMAND -X"
}


# Parse command-line options
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --help) show_help; exit 0 ;;
        --no-utils) INSTALL_UTILS=false ;;
        --install-global) INSTALL_GLOBAL=true ;;
        --appimage)
          if [[ -n "$2" && ! "$2" =~ ^- ]]; then
              NVIM_APPIMAGE_URL="$2"
              shift
          else
              log_error "Error: --appimage requires a URL argument"
              exit 1
          fi
          ;;
        *) echo "Unknown parameter passed: $1"; show_help; exit 1 ;;
    esac
    shift
done

main
