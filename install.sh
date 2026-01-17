#!/usr/bin/env bash
# git-chord installer

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_INSTALL_DIR="$HOME/.git-chord"
INSTALL_DIR="${GIT_CHORD_DIR:-$DEFAULT_INSTALL_DIR}"
REPO_URL="${GIT_CHORD_REPO_URL:-git@github.com:socket-link/git-chord.git}"

# Prefer local repo if we're running inside it and no explicit install dir is set
LOCAL_REPO_DIR=""
if git -C "$SCRIPT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  REPO_TOPLEVEL="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
  if [ -f "$REPO_TOPLEVEL/git-chord.zsh" ]; then
    LOCAL_REPO_DIR="$REPO_TOPLEVEL"
  fi
fi

if [ -z "${GIT_CHORD_DIR:-}" ] && [ -n "$LOCAL_REPO_DIR" ]; then
  INSTALL_DIR="$LOCAL_REPO_DIR"
fi

echo "Installing git-chord to $INSTALL_DIR..."

# Clone or update (unless using local repo)
if [ "$INSTALL_DIR" = "$LOCAL_REPO_DIR" ] && [ -n "$LOCAL_REPO_DIR" ]; then
  echo "Using local repo at $INSTALL_DIR"
elif [ -d "$INSTALL_DIR" ]; then
  echo "Updating existing installation..."
  cd "$INSTALL_DIR" && git pull
else
  git clone "$REPO_URL" "$INSTALL_DIR"
fi

# Detect shell config
if [ -f "$HOME/.zshrc" ]; then
  SHELL_RC="$HOME/.zshrc"
elif [ -f "$HOME/.zprofile" ]; then
  SHELL_RC="$HOME/.zprofile"
else
  echo "Could not find .zshrc or .zprofile"
  echo "Add this line manually to your shell config:"
  echo "  source $INSTALL_DIR/git-chord.zsh"
  exit 0
fi

# Add source line if not present
SOURCE_LINE="source $INSTALL_DIR/git-chord.zsh"
if ! grep -qF "git-chord.zsh" "$SHELL_RC"; then
  echo "" >> "$SHELL_RC"
  echo "# git-chord - vim-style composable git commands" >> "$SHELL_RC"
  echo "$SOURCE_LINE" >> "$SHELL_RC"
  echo "Added to $SHELL_RC"
else
  echo "Already in $SHELL_RC"
fi

echo ""
echo "✓ Installed! Run 'source $SHELL_RC' or open a new terminal."
echo "  Type 'ghelp' to see available commands."
