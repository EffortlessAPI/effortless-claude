#!/bin/bash
# Install the Effortless Rulebooks skill for Claude Code
# Usage: bash install.sh

set -e

SKILL_NAME="effortless-rulebooks"
SKILL_DIR="$HOME/.claude/skills/$SKILL_NAME"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing Claude Code skill: $SKILL_NAME"

# Create the skills directory if needed
mkdir -p "$HOME/.claude/skills"

# Check if already installed
if [ -d "$SKILL_DIR" ] || [ -L "$SKILL_DIR" ]; then
  echo "Existing installation found at $SKILL_DIR — updating..."
  rm -rf "$SKILL_DIR"
fi

# Copy skill files
mkdir -p "$SKILL_DIR"
cp "$SCRIPT_DIR/SKILL.md" "$SKILL_DIR/SKILL.md"
cp "$SCRIPT_DIR/README.md" "$SKILL_DIR/README.md"

echo ""
echo "Installed to $SKILL_DIR"
echo "The skill will activate automatically in your next Claude Code session."
echo "Test it by opening an ERB project and asking: \"What tables are in this rulebook?\""
