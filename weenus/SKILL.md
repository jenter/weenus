---
name: weenus
description: Use when creating a new skill, editing an existing one, listing what's in this repo, checking SKILL.md frontmatter for packaging errors, or rolling an edit out to Claude Code and/or the Claude app. Covers the jenter/weenus skills repo specifically.
---

# Weenus

This is the meta-skill for managing the `jenter/weenus` repo itself — the
library of skills shared across Claude Code (personal + work machines) and
the Claude app (personal + work accounts). Load `SKILLS-ARCHITECTURE.md` in
the repo root for the full design rationale; this file is the day-to-day
"how do I do X" companion to it.

## Repo layout

```
weenus/
  <skill-name>/SKILL.md   # one directory per skill — this is the unit
  new-skill.sh            # scaffold a new skill directory
  install.sh              # symlink every */SKILL.md into ~/.claude/skills/
  SKILLS-ARCHITECTURE.md  # design doc: tradeoffs, rollout runbook, open items
  .gitignore              # excludes generated *.zip upload artifacts
```

Every skill is self-contained in its own top-level directory. Nothing about
one skill should reference another skill's internals.

## Frontmatter rules (hard constraint)

Only six fields are accepted by claude.ai's uploader, the Skills API, and
`package_skill.py`:

```
name, description, license, compatibility, metadata, allowed-tools
```

Any other field — `argument-hint`, `context: fork`,
`disable-model-invocation`, anything Claude-Code-specific — fails packaging
with a hard error rather than being silently dropped. If a skill needs a
Claude-Code-only field, that's a signal it needs a second, separate
variant, not a relaxed shared one. When editing or reviewing a SKILL.md,
check its frontmatter keys against this list before anything else.

`description` carries the real weight: it's the only part of the skill
that sits in context before invocation, so it must describe *when to use
this skill* concretely enough for the model to route to it correctly —
mirror the phrasing a user would actually type, the way `hotdog/SKILL.md`
and this file both do.

## Creating a new skill

1. `./new-skill.sh <name>` — scaffolds `<name>/SKILL.md` from a template
   with the frontmatter already correct. Refuses to overwrite an existing
   directory.
2. Fill in `description` first — get the trigger phrasing right before
   writing the body.
3. Write the instructions body. Keep it procedural (what to do), not
   reference material dumped in — if a skill needs reference data, put it
   in a supporting file alongside SKILL.md and point to it from the body
   (open item #2 in SKILLS-ARCHITECTURE.md flags that multi-file bundles
   are untested for chat upload — test with the personal account before
   relying on this for something that matters).
4. `./install.sh` to symlink it into `~/.claude/skills/` on this machine.
5. Test in a **new** Claude Code session (skills load at session start).
6. If it also needs to run in the Claude app, follow the "Rollout" section
   of `SKILLS-ARCHITECTURE.md` (zip, upload per account).

## Updating an existing skill

Edit the file directly, then follow **"Runbook: rolling out a skill
update"** in `SKILLS-ARCHITECTURE.md` — it covers both Claude Code
(git pull + conditional `install.sh`) and the Claude app (re-zip + re-upload
per account) including the work-machine-specific gotchas (git access,
Skills being greyed out under Enterprise, keeping client content out of
this repo).

## Listing what's here

```bash
for f in */SKILL.md; do awk -F': ' '/^name:/{n=$2} /^description:/{d=$0} END{print n" — "d}' "$f"; done
```

Or just `ls -d */` and read each `SKILL.md` — this repo is small enough
that a directory listing plus a couple of reads is faster than tooling.

## Auditing frontmatter across all skills

Before a push, a quick sanity check that nothing will fail packaging:

```bash
for f in */SKILL.md; do
  awk '/^---$/{c++; next} c==1' "$f" | grep -oE '^[a-z-]+:' | sed 's/://' \
    | grep -vE '^(name|description|license|compatibility|metadata|allowed-tools)$' \
    && echo "  ^ disallowed field(s) in $f"
done
```
No output means every skill's frontmatter is clean.

## Broken symlink check

If a skill doesn't fire in Claude Code, confirm the symlink actually
resolves:

```bash
ls -la ~/.claude/skills/ | grep -v '\->.*weenus'   # anything NOT pointing here
find ~/.claude/skills/ -maxdepth 1 -type l -exec test ! -e {} \; -print  # broken links
```
