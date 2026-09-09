#!/bin/bash
set -e

# Scaffold a new skill directory with a correctly-shaped SKILL.md.
# Usage: ./new-skill.sh <skill-name>

if [ -z "$1" ]; then
  echo "Usage: ./new-skill.sh <skill-name>"
  exit 1
fi

NAME="$1"
# Title-case the first letter for the H1 heading. Done with awk rather than
# bash's ${NAME^} because macOS ships bash 3.2, which lacks that operator.
TITLE="$(printf '%s' "$NAME" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
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

# ${TITLE}

TODO — procedural instructions for what Claude should do once this skill
fires. Keep it action-oriented; put reference data in a separate file
alongside this one if needed, and point to it from here.
EOF

echo "✓ Created $SKILL_DIR/SKILL.md"

# The scaffold's description is a non-empty TODO placeholder, so this
# passes cleanly — it's here as a sanity check on the scaffold itself
# (catches a bug in this script, not the TODO content), and so the
# validator's output is already familiar before it matters at commit time.
python3 "$REPO_DIR/validate-skill.py" "$SKILL_DIR" || true

echo "  Next: edit the description and body, then run ./install.sh"
