---
name: skill-idea
description: Use when the user wants to turn an idea into a new Claude Skill for this repo, or wants to brainstorm what a skill could do before committing to one — triggers on phrasing like "let's make a skill for X", "I want a skill that...", "how could I use this as a skill", "give me ideas", or "brainstorming". Asks clarifying questions until the trigger and behavior are clear, then scaffolds and writes the skill; if the idea doesn't actually fit a Skill, explains why and suggests the better mechanism instead.
---

# Skill Idea

Meta-skill for turning a raw idea into a new skill in this repo — or
steering it toward a better-fitting mechanism when a Skill isn't the
right shape for it. Depends on the conventions in `weenus/SKILL.md`
(frontmatter rules, `new-skill.sh`, `validate-skill.py`, `install.sh`) —
this file is the front door that decides *whether* and *what* to build;
`weenus/SKILL.md` is the how.

## Two modes

### Brainstorm mode

Triggered by phrasing like "how could I use this", "what are your
ideas", "brainstorming", "give me options" — no commitment to build
anything yet.

- Offer 2-4 concrete, distinct angles on what a skill could do with the
  input. Each one: a trigger phrase plus what it'd actually do — not
  abstract categories.
- Don't scaffold anything. Wait for the user to pick a direction or say
  "build it."

### Build mode

Triggered by phrasing like "let's make a skill for X", "make this a
skill", or by the user picking a direction after brainstorm mode.

1. Read what they already gave you first — don't ask about anything
   their input already answered.
2. Ask only what's still needed to write a real `description` and body.
   Use AskUserQuestion for concrete choices, free text for open-ended
   ones. Typical gaps worth asking about:
   - **Trigger phrasing** — what would they actually type to fire this?
     Shapes `description` directly.
   - **Scope** — specific to this repo/project, or general-purpose?
   - **Action** — what should Claude actually *do* once it fires — a
     procedure, not a vibe.
   - **Inputs/outputs** — supporting files needed, or a specific
     artifact produced?
   - **Surface** — Claude Code only, or does it need the Claude app too?
     (Determines whether Code-only frontmatter fields are off the table —
     see the frontmatter rules in `weenus/SKILL.md`.)
3. Stop asking once a concrete, non-generic `description` and a
   procedural body are both writable — don't pad with more questions for
   their own sake.
4. Before creating anything, check fit against "When a skill is the
   wrong shape" below. If it's a poor fit, say so and stop — don't
   scaffold it anyway.
5. If it fits:
   ```bash
   ./new-skill.sh <name>
   ```
   then write the real `description` and body directly with Edit — don't
   leave the TODO placeholders for the user to fill in themselves. Run
   ```bash
   ./validate-skill.py <name>
   ```
   and fix anything it flags, then `./install.sh`.
6. Tell the user how to test it (new Claude Code session, the trigger
   phrase). Remind them the Claude app needs a separate zip-upload per
   account if they want it there too — point at the rollout runbook in
   `SKILLS-ARCHITECTURE.md` rather than re-explaining it.
7. Don't commit or push unless asked — having it installed locally is
   enough until they've tried it.

## When a skill is the wrong shape

A Skill is the right tool for a **reusable procedure Claude should
follow when a recognizable situation comes up** — not for everything.
Say so plainly and name the better mechanism when the idea is actually:

- **A one-off task** ("do X right now") — just do it, no skill needed.
- **Something that must fire on an event, not a phrase** ("every time I
  commit," "whenever a file changes") — that's a hook in
  `settings.json`, not a Skill; Skills fire from conversation, not
  lifecycle events. Point at the `update-config` skill.
- **A fact to remember about the user or project**, not a procedure —
  that's a memory file, not a Skill.
- **Reference material with no action attached** (a glossary, a style
  guide to consult) — a plain doc is simpler; only make it a Skill if
  there's a real trigger and action, not just content to read.
- **Something needing a live external system with credentials** (an
  API, a database) — that's an MCP connector, not a Skill. A Skill can
  still wrap *using* the connector, but the connection itself isn't one.
- **A one-shot personal preference with no repeatable trigger** ("always
  answer in French") — a memory/preference note, not a Skill.

When redirecting, name the specific alternative, and if it's cheap to do
directly — writing the memory file, pointing at the exact hook config —
just do that instead of only describing it.

## Example

Input: "I keep having to explain our deploy checklist to Claude every
time. Can we make a skill?"

This is a good fit — recognizable trigger ("deploy", "checklist"),
repeatable procedure. Ask what the checklist actually contains if not
given, what repo/project it's scoped to, and whether it needs to run in
the app too — then build it per the steps above.

Input: "Every time I push to main, run the linter."

Redirect: that's an event, not a conversational trigger — a pre-push git
hook or CI step is the right mechanism, not a Skill. Offer to write the
hook directly if this repo doesn't already have one.
