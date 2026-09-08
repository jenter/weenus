#!/usr/bin/env python3
"""Validate SKILL.md files against the claude.ai Skills upload / Skills API
spec — the strict subset of rules that apply when a skill needs to work
both in Claude Code (which accepts a much broader frontmatter) and as an
app upload (which hard-errors on anything outside a fixed field set).

Rules enforced here (see SKILLS-ARCHITECTURE.md's "Frontmatter constraint"
for the design rationale):

  - Frontmatter must open with '---' and close with a second '---'.
  - Only these keys are allowed: name, description, license, compatibility,
    metadata, allowed-tools. Anything else is what claude.ai's uploader
    hard-errors on ("Unexpected key(s) in SKILL.md frontmatter: ...").
  - 'name' is required; if it doesn't match the containing directory name,
    that's a warning (not a hard error) — install.sh and new-skill.sh both
    key off the directory name, so a mismatch is confusing but not fatal.
  - 'description' is required — it's the only part of a skill loaded
    before invocation, so an empty one means the skill can never be routed
    to automatically.
  - name + description combined must be <=1536 chars — claude.ai truncates
    listings at that length.
  - 'compatibility', if present, must be <=500 chars.
  - 'metadata', if present, must be a flat map (no nested dict/list values).
  - 'allowed-tools', if present, must be a string or a list.

No PyYAML dependency — this repo's frontmatter is simple enough (flat
top-level keys, occasional multi-line description) that a small hand-rolled
parser is more honest than pretending to be a general YAML parser. If a
skill's frontmatter gets more complex than this handles, that's a sign to
add PyYAML as a real dependency rather than patch this further.

Usage:
  ./validate-skill.py                    # validate every */SKILL.md found
  ./validate-skill.py <dir> [<dir> ...]   # validate specific skill dirs
"""
import sys
import os
import re
import glob

ALLOWED_KEYS = {"name", "description", "license", "compatibility", "metadata", "allowed-tools"}
MAX_COMPATIBILITY = 500
MAX_NAME_PLUS_DESCRIPTION = 1536


def parse_frontmatter(path):
    with open(path) as f:
        text = f.read()

    if not (text.startswith("---\n") or text.startswith("---\r\n")):
        return None, "must open with '---' on the first line (no frontmatter found)"

    parts = text.split("---", 2)
    if len(parts) < 3:
        return None, "frontmatter block not closed with a second '---'"

    return parse_flat_yaml(parts[1]), None


def parse_flat_yaml(block):
    """Minimal parser for flat 'key: value' frontmatter with optional
    multi-line continuations (indented lines append to the previous key).
    Handles the shapes this repo's skills actually use — not a general
    YAML parser."""
    data = {}
    cur_key = None
    for line in block.splitlines():
        if not line.strip() or line.strip().startswith("#"):
            continue
        m = re.match(r'^([a-zA-Z_-]+):\s?(.*)$', line)
        if m:
            cur_key, val = m.group(1), m.group(2).strip()
            data[cur_key] = val
        elif line.startswith((" ", "\t")) and cur_key is not None:
            data[cur_key] = (data[cur_key] + " " + line.strip()).strip()
        # anything else (unexpected indentation with no active key) is ignored
    return data


def validate_dir(skill_dir):
    errors, warnings = [], []
    name_from_dir = os.path.basename(os.path.normpath(skill_dir))
    skill_md = os.path.join(skill_dir, "SKILL.md")

    if not os.path.isfile(skill_md):
        return [f"{skill_dir}: no SKILL.md found"], []

    data, err = parse_frontmatter(skill_md)
    if err:
        return [f"{skill_md}: {err}"], []

    extra = sorted(set(data.keys()) - ALLOWED_KEYS)
    if extra:
        errors.append(
            f"{skill_md}: disallowed frontmatter field(s) {extra} — "
            f"claude.ai upload only accepts {sorted(ALLOWED_KEYS)}"
        )

    name = data.get("name")
    if not name:
        errors.append(f"{skill_md}: missing required 'name' field")
    elif name != name_from_dir:
        warnings.append(
            f"{skill_md}: name '{name}' does not match directory '{name_from_dir}' "
            f"(install.sh and new-skill.sh both key off the directory name)"
        )

    description = data.get("description")
    if not description:
        errors.append(
            f"{skill_md}: missing 'description' — required for the model to "
            f"auto-invoke this skill"
        )
    else:
        combined = len(name or "") + len(description)
        if combined > MAX_NAME_PLUS_DESCRIPTION:
            errors.append(
                f"{skill_md}: name+description is {combined} chars, over the "
                f"{MAX_NAME_PLUS_DESCRIPTION}-char limit claude.ai truncates "
                f"listings at"
            )

    compatibility = data.get("compatibility")
    if compatibility and len(compatibility) > MAX_COMPATIBILITY:
        errors.append(
            f"{skill_md}: 'compatibility' is {len(compatibility)} chars, over "
            f"the {MAX_COMPATIBILITY}-char limit"
        )

    return errors, warnings


def main(argv):
    dirs = argv[1:] if len(argv) > 1 else sorted(
        os.path.dirname(p) for p in glob.glob("*/SKILL.md")
    )

    all_errors, all_warnings = [], []
    for d in dirs:
        errs, warns = validate_dir(d)
        all_errors += errs
        all_warnings += warns

    for w in all_warnings:
        print(f"WARN  {w}")
    for e in all_errors:
        print(f"FAIL  {e}")

    if all_errors:
        print(f"\n{len(all_errors)} error(s) — not safe to upload/package.")
        return 1

    print(f"\n{len(dirs)} skill(s) checked, {len(all_warnings)} warning(s), 0 errors.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
