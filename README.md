# remote-copy.nvim

A simple Bash script to deploy Neovim on a remote machine via SSH.
It installs the Neovim AppImage, copies your local configuration, and (optionally) installs additional utilities.

## Installation

1. Download the `nvim-sync.sh` file.
2. Look at the contents of the script. **Never blindly trust downloaded scripts.**
3. Use `chmod u+x nvim-sync.sh` to make the script executable.

## Requirements

- SSH access to remote machine
- `rsync` installed locally
- Debian-based remote machine

## Usage

```bash
./nvim-sync.sh [options]

Options:
  --help              Show this help message
  --no-utils          Does not install additional utils (see above)
  --install-global    Adds nvim to the global path instead of the shell configuration file
  --appimage [URL]    Allows to specify the URL to the App Image. Default is $NVIM_APPIMAGE_URL
```

### Additional Utils

Unless specified using the `--no-additional` flag, the script installs additional utilities which support Neovim in general or specifically in an SSH-Environment:

- xclip: Used for copying into local register from remote NeoVim. Requires SSH session to be started with -X flag
- python3-venv: Virtual environments are needed for vim functionality
- rigrep: Used for fuzzy finding (for example in telescope.nvim)
