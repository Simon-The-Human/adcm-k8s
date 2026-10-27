#!/usr/bin/env sh

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { printf "${GREEN}[INFO]${NC}  %s\n" "$1"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$1"; }
header(){ printf "${CYAN}==== %s ====${NC}\n" "$1"; }

header "Development environment setup"

# --- 1. Install Nix (if missing) ---
if command -v nix >/dev/null 2>&1; then
    info "Nix is already installed."
else
    warn "Nix is not installed."
    printf "Install Nix with Determinate Installer (recommended)? [Y/n] "
    read -r answer
    if [ "$answer" = "n" ] || [ "$answer" = "N" ]; then
        echo "Installation aborted."
        exit 1
    fi
    info "Installing Nix..."
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
    # Reload Nix environment for the current session
    if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
        # shellcheck disable=SC1091
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    elif [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
        # shellcheck disable=SC1090
        . "$HOME/.nix-profile/etc/profile.d/nix.sh"
    fi
    info "Nix installed successfully."
fi

# --- 2. Install direnv via Nix ---
if command -v direnv >/dev/null 2>&1; then
    info "direnv is already installed."
else
    info "Installing direnv via nix profile..."
    nix profile add nixpkgs#direnv
    info "direnv installed."
fi

# --- 3. Add direnv hook to shell rc files ---
add_hook_if_missing() {
    local file="$1"
    # Intentional: write literal eval "$(direnv hook ...)" into rc files
    # shellcheck disable=SC2016
    local hook_cmd='eval "$(direnv hook bash)"'
    # zsh users
    if [[ "$file" == *".zshrc" ]]; then
        # shellcheck disable=SC2016
        hook_cmd='eval "$(direnv hook zsh)"'
    fi

    if [ -f "$file" ]; then
        if grep -q "direnv hook" "$file" 2>/dev/null; then
            info "direnv hook already present in $file"
        else
            {
                echo ""
                echo "# direnv hook"
                echo "$hook_cmd"
            } >> "$file"
            info "Added direnv hook to $file"
        fi
    fi
}

add_hook_if_missing "$HOME/.bashrc"
add_hook_if_missing "$HOME/.zshrc"

# --- 4. Ensure .envrc contains 'use flake' ---
ENVRC_FILE=".envrc"
if [ ! -f "$ENVRC_FILE" ]; then
    echo "use flake" > "$ENVRC_FILE"
    info "Created .envrc with 'use flake'"
elif ! grep -q "^use flake" "$ENVRC_FILE"; then
    echo "use flake" >> "$ENVRC_FILE"
    info "Added 'use flake' to existing .envrc"
else
    info ".envrc already contains 'use flake'"
fi

# --- 5. Final instructions ---
echo ""
header "Setup complete"
echo "Next steps:"
echo "  1. Restart your terminal (exec) OR run: source ~/.bashrc (or ~/.zshrc)"
echo "  2. Navigate to this project directory and run: direnv allow"
echo ""
echo "After that, every time you cd into this directory,"
echo "the full development environment will activate automatically."

