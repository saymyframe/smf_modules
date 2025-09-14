#!/usr/bin/env bash
# install_firebase_linux.sh
# Purpose: Ensure Firebase CLI is installed on Linux.
# Flow: check firebase -> ensure node via NVM (user scope, no sudo) -> npm i -g firebase-tools -> add npm bin to PATH -> verify
# Notes:
# - Uses NVM to avoid sudo and system package managers.
# - Works even if `git` is missing (forces tarball install).
# - PATH updates affect new terminals; verification uses the absolute npm bin path.

set -euo pipefail

command_exists() { command -v "$1" >/dev/null 2>&1; }

ensure_nvm_user() {
  # Require curl or wget
  if ! command_exists curl && ! command_exists wget; then
    echo "curl or wget is required to install nvm. Please install one and re-run." >&2
    exit 1
  fi

  # Prefer curl, fallback to wget
  if command_exists curl; then
    DL_CMD='curl -fsSL'
    SRC_CMD='curl -fsSL'
  else
    DL_CMD='wget -qO-'
    SRC_CMD='wget -qO-'
  fi

  # Force tarball install path (no git required)
  export NVM_INSTALL_GIT=0
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

  # Install NVM (idempotent)
  if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    eval "$SRC_CMD https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh" | bash
  fi

  # Load NVM for this shell
  # shellcheck source=/dev/null
  . "$NVM_DIR/nvm.sh"
}

ensure_node_user() {
  if ! command_exists node; then
    nvm install --lts
  fi
  if ! command_exists npm; then
    # If npm still not on PATH, try re-sourcing NVM
    # shellcheck source=/dev/null
    . "$NVM_DIR/nvm.sh"
  fi
}

ensure_path_contains() {
  case ":$PATH:" in
    *":$1:"*) return 0 ;;
    *) return 1 ;;
  esac
}

append_path_to_shell_rc_linux() {
  local entry="$1"
  # default to bash; if zsh is used, prefer .zshrc
  local rc="$HOME/.bashrc"
  if [ -n "${ZSH_VERSION:-}" ] || [ -n "${SHELL:-}" ] && [[ "${SHELL:-}" == *"zsh" ]]; then
    rc="$HOME/.zshrc"
  fi
  touch "$rc"
  if ! grep -Fq "$entry" "$rc" 2>/dev/null; then
    echo "export PATH=\"\$PATH:$entry\"" >> "$rc"
    echo "PATH updated in $rc with: $entry (open a new terminal to take effect)"
  fi
}

# 1) Already have firebase?
if command_exists firebase; then
  echo "Firebase CLI already installed"
  exit 0
fi

# 2) Ensure NVM and Node (user scope)
ensure_nvm_user
ensure_node_user

# 3) Install Firebase CLI
npm i -g firebase-tools

# 4) Ensure global npm bin in PATH (for future shells)
npm_bin="$(npm bin -g 2>/dev/null || true)"
if [ -n "$npm_bin" ] && ! ensure_path_contains "$npm_bin"; then
  append_path_to_shell_rc_linux "$npm_bin"
fi

# 5) Verify (prefer absolute path so we don't depend on PATH refresh)
if [ -n "$npm_bin" ] && [ -x "$npm_bin/firebase" ]; then
  "$npm_bin/firebase" --version
  exit 0
fi
# fallback if PATH already updated in current shell
if command_exists firebase; then
  firebase --version
  exit 0
fi

echo "Firebase CLI verification failed" >&2
exit 1
