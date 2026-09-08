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
  install.sh              # symlink every */SKILL.md into ~/.claude/skills/,
                           # and enable the pre-commit validation hook below
  validate-skill.py       # enforces the frontmatter rules below
  .githooks/pre-commit    # runs validate-skill.py on any commit touching
                           # a SKILL.md; enabled by install.sh
  SKILLS-ARCHITECTURE.md  # design doc: tradeoffs, rollout runbook, open items
  .gitignore              # excludes generated *.zip upload artifacts
```

Every skill is self-contained in its own top-level directory. Nothing about
one skill should reference another skill's internals.

## Frontmatter rules (hard constraint)

Claude Code itself accepts a much broader set of frontmatter fields
(`when_to_use`, `argument-hint`, `disable-model-invocation`, `model`,
`context`, and more). This repo intentionally targets the **narrower**
set claude.ai's Skills uploader and the Skills API accept, so one SKILL.md
works unchanged on every surface in the table above. Only six fields are
allowed there:

```
name, description, license, compatibility, metadata, allowed-tools
```

Any other field — `argument-hint`, `context: fork`,
`disable-model-invocation`, anything Claude-Code-specific — fails
claude.ai's upload with a hard error rather than being silently dropped
(confirmed against current Claude Code docs, not just observed once). If a
skill needs a Claude-Code-only field, that's a signal it needs a second,
separate variant, not a relaxed shared one.

This is enforced, not just documented — see "Validating a skill" below.
Additional constraints worth knowing when writing one:

- `name` — required. Should match the containing directory name (that's
  what `install.sh`/`new-skill.sh` key off); a mismatch is a warning, not
  a hard error, but fix it anyway.
- `description` — required; it's the only part of the skill that sits in
  context before invocation, so it must describe *when to use this skill*
  concretely enough for the model to route to it correctly — mirror the
  phrasing a user would actually type, the way `hotdog/SKILL.md` does.
  `name` + `description` combined must stay under 1536 characters —
  claude.ai truncates listings at that length.
- `compatibility` — optional, free text, capped at 500 characters.
- `metadata` — optional, must be a flat key-value map (no nested
  dicts/lists — Claude Code doesn't act on its contents, but nesting isn't
  guaranteed to survive upload).
- `allowed-tools` — optional, a string or a YAML list of tool names.

There is no official `package_skill.py`; the closest thing Claude Code
ships is `claude plugin validate <dir>`, but that validates a *plugin*
manifest (`.claude-plugin/plugin.json`) and doesn't apply to a bare skill
directory like the ones in this repo — hence `validate-skill.py` below.

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

## Validating a skill

`validate-skill.py` checks the frontmatter rules above (disallowed keys,
missing name/description, length limits, malformed metadata/allowed-tools)
and is what actually enforces them — not just this file's prose:

```bash
./validate-skill.py                 # every */SKILL.md in the repo
./validate-skill.py hotdog weenus   # specific skill directories
```

Exit code is non-zero if any skill has an error (warnings don't fail the
run). This runs automatically as a **pre-commit hook** — any commit
touching a `SKILL.md` gets validated before it's allowed through, wired
up by `install.sh` via `git config core.hooksPath .githooks`. If a commit
is blocked, fix what it prints, or `git commit --no-verify` to bypass
(only for a deliberate exception — not the default path). `new-skill.sh`
also runs this on the scaffold it just created, so a fresh skill's
placeholder description shows up as a failure immediately rather than
silently at commit time.

When creating or editing a skill by hand rather than through
`new-skill.sh`, run `./validate-skill.py <the-skill-dir>` before
considering it done — the hook is a safety net for what you push, not a
substitute for checking while you're still writing it.

## Broken symlink check

If a skill doesn't fire in Claude Code, confirm the symlink actually
resolves:

```bash
ls -la ~/.claude/skills/ | grep -v '\->.*weenus'   # anything NOT pointing here
find ~/.claude/skills/ -maxdepth 1 -type l -exec test ! -e {} \; -print  # broken links
```
