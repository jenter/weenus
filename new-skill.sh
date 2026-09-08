#!/bin/bash
set -e

# Scaffold a new skill directory with a correctly-shaped SKILL.md.
# Usage: ./new-skill.sh <skill-name>

if [ -z "$1" ]; then
  echo "Usage: ./new-skill.sh <skill-name>"
  exit 1
fi

NAME="$1"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$REPO_DIR/$NAME"

if [ -e "$SKILL_DIR" ]; then
  echo "Error: $SKILL_DIR already exists — not overwriting."
  exit 1
fi

mkdir -p "$SKILL_DIR"

cat > "$SKILL_DIR/SKILL.md" <<EOF
---
name: $NAME
description: TODO — describe exactly when this skill should fire, in the
  phrasing a user would actually type. This is the only part of the skill
  loaded before invocation, so be concrete.
---

# ${NAME^}

TODO — procedural instructions for what Claude should do once this skill
fires. Keep it action-oriented; put reference data in a separate file
alongside this one if needed, and point to it from here.
EOF

echo "✓ Created $SKILL_DIR/SKILL.md"
echo "  Next: edit the description and body, then run ./install.sh"
