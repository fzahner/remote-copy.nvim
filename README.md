# remote-copy.nvim

A simple Bash script to deploy Neovim on a remote machine via SSH.
It installs the Neovim AppImage, copies your local configuration, and (optionally) installs additional utilities.

## Installation

1. Download the `nvim-sync.sh` file.
2. Use `chmod u+x nvim-sync.sh` to make the script executable.

## Usage

```bash
./nvim-sync.sh [options]

Options
    --help → Show help message
    --no-additional → Skip installing extra utilities
    --appimage [URL] → Use custom Neovim AppImage URL
```

## Requirements

- SSH access to remote machine
- `rsync` installed locally
- Debian-based remote machine
