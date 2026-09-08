#!/bin/bash
set -e

# Install skills by symlinking into ~/.claude/skills/

SKILLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_SKILLS_DIR="${HOME}/.claude/skills"

# Ensure the target directory exists
mkdir -p "$CLAUDE_SKILLS_DIR"

# Find all skill directories (those with SKILL.md)
for skill_path in "$SKILLS_DIR"/*/SKILL.md; do
  if [ -f "$skill_path" ]; then
    skill_name=$(basename "$(dirname "$skill_path")")
    skill_dir="$(dirname "$skill_path")"
    target="$CLAUDE_SKILLS_DIR/$skill_name"

    # Remove existing symlink or directory
    if [ -L "$target" ] || [ -e "$target" ]; then
      rm -rf "$target"
    fi

    # Create symlink
    ln -s "$skill_dir" "$target"
    echo "✓ Linked $skill_name"
  fi
done

echo "Skills installed to $CLAUDE_SKILLS_DIR"
