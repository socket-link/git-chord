#!/usr/bin/env bash
# git-chord installer

set -e

INSTALL_DIR="${GIT_CHORD_DIR:-$HOME/.git-chord}"
REPO_URL="https://github.com/user/git-chord.git"

echo "Installing git-chord to $INSTALL_DIR..."

# Clone or update
if [ -d "$INSTALL_DIR" ]; then
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
