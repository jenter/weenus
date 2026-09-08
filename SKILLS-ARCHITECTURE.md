# Skills Architecture — cross-surface distribution

Repo: https://github.com/jenter/weenus

## Problem

One library of skills, reachable from six places:

| Surface | Mechanism |
|---|---|
| Personal Claude app (web/desktop) | account-level: uploaded skill or connector |
| Work Claude app (web/desktop) | account-level: uploaded skill or connector |
| Personal iPhone | inherits from personal account, no per-device setup |
| Work iPhone | inherits from work account, no per-device setup |
| Personal Claude Code | `~/.claude/skills/` on that machine |
| Work Claude Code | `~/.claude/skills/` on that machine |

Six surfaces collapse to **two accounts plus two filesystems**. Skills and
connectors are account-level, so mobile requires no separate work.

## The core tradeoff

Nothing today gives private storage + sync + automatic invocation
simultaneously. Pick two:

- **Uploaded skill** (zip → Customize > Skills): private, auto-invoked,
  **no sync**. Two accounts = two uploads, permanently.
- **Private GitHub repo + GitHub connector**: private, **synced** (reads
  current HEAD at request time), but **not auto-invoked** — you name the
  skill in your prompt.

A saved login or bearer token is not an option. When Claude in the app
fetches a URL, the request originates server-side and carries no session,
cookie, or stored credential. There is nowhere to put the secret.

## Chosen design

Git is the source of truth. Two delivery paths off it.

```
weenus/
  hotdog/SKILL.md          # test skill
  weenus/SKILL.md          # meta-skill: manages this repo's skills
  <skill-name>/SKILL.md    # one directory per skill
  new-skill.sh             # scaffold a new skill directory
  install.sh               # symlink skills into ~/.claude/skills/,
                            # enable the pre-commit validation hook
  validate-skill.py        # enforces the frontmatter constraint below
  .githooks/pre-commit     # runs validate-skill.py on commit
  .gitignore               # excludes generated *.zip upload artifacts
  SKILLS-ARCHITECTURE.md   # this file
```

See `weenus/SKILL.md` for the day-to-day workflow — creating a new skill,
checking frontmatter, listing what's here — as a companion to this doc's
design rationale.

**Claude Code (both machines):** `install.sh` symlinks each skill directory
into `~/.claude/skills/<name>`. Claude Code follows symlinks and reads
SKILL.md from the target, so a `git pull` updates both machines instantly.

**App surfaces (both accounts):** zip each skill directory, upload under
Customize > Skills. Do this per account. Mobile follows automatically.

**Optional reverse sync:** if uploads become the source of truth instead,
run `CLAUDE_CODE_SYNC_SKILLS=1 claude -p "list your skills"` once per
machine. Enabled account skills download to `~/.claude/skills/synced/` and
persist across sessions. Re-run after any change on claude.ai.

## Frontmatter constraint

Author to the six fields accepted by claude.ai upload and the Skills API
(Claude Code itself accepts a much broader set — `when_to_use`,
`argument-hint`, `model`, `context`, and more — but those fail the
narrower upload path):

`name`, `description`, `license`, `compatibility`, `metadata`, `allowed-tools`

Any other field (`argument-hint`, `context: fork`,
`disable-model-invocation`) fails packaging with a hard error rather than
being ignored. Staying inside these six means one file works in both places
unchanged. Skills needing Claude Code-only features get a second variant,
not a degraded shared one. Two more limits worth knowing: `compatibility`
caps at 500 characters, and `name` + `description` combined caps at 1536
(claude.ai truncates listings past that).

There is no official `package_skill.py` — that was this doc's earlier,
unverified assumption. Claude Code's own validator,
`claude plugin validate <dir>`, checks a *plugin* manifest
(`.claude-plugin/plugin.json`) and doesn't apply to a bare skill directory
like the ones here. This repo enforces the constraint itself instead:
`validate-skill.py`, run automatically as a pre-commit hook (enabled by
`install.sh`) — see `weenus/SKILL.md`'s "Validating a skill" section.

## Runbook: rolling out a skill update

Do this any time a skill's files change, on whichever machine you edited from
first.

### Claude Code — personal + work

1. Edit the skill, then `git add`, `commit`, `push` from whichever machine
   made the change.
2. On the **other** machine: `cd weenus && git pull`.
3. Symlinks point at file contents already in the repo, so a `git pull`
   alone is enough for edits to existing files. Only re-run `install.sh`
   when a **new** skill directory was added, or a symlink is missing/broken:
   ```bash
   ./install.sh   # idempotent, safe to re-run anytime
   ```
4. Start a **new** Claude Code session — skills load at session start, so an
   already-open session won't see the change — and test.

### Claude app — personal + work accounts

Skills do not sync from git into the app. Each account's upload is a
separate manual step, and there is no re-run of a script for this half.

1. `cd weenus && zip -r hotdog.zip hotdog` (repeat per skill; always rerun
   after an edit — the zip is a snapshot, not a link).
2. Log into claude.ai (or the desktop app) under the **relevant account**.
3. Settings > Customize (or Capabilities) > Skills > find the existing
   skill entry > replace/re-upload with the new zip (delete + re-add if
   there's no in-place replace on that surface).
4. If the same edit should also apply to the **other** account, repeat
   steps 2-3 there — uploads are per-account, not shared.
5. Mobile (iPhone, both personal and work) inherits automatically once the
   matching account's upload is updated — no separate device step.

### Work-machine specifics

- **Claude Code:** the work machine needs the same git access as personal —
  clone/pull with credentials (SSH key or HTTPS auth) that can read
  `jenter/weenus`, since it's a private repo.
- **Claude app:** if Settings > Skills is greyed out on the work account,
  that's Open Item 1 below — an Org Owner must enable *Code execution and
  file creation* + *Skills* under Organization settings before you can
  upload anything there.
- **Content boundary:** don't put company-sensitive skill content in this
  repo — see Open Item 3 below. Generic engineering skills (like `hotdog`)
  are fine; anything with client specifics, internal endpoints, or process
  detail belongs in company git instead, reachable only from work Claude
  Code.

## Open items

1. **Work account may not permit personal skills.** On Enterprise, an Owner
   must enable both *Code execution and file creation* and *Skills* under
   Organization settings > Skills before members can upload their own. For
   HIPAA-ready or otherwise regulated configurations these are off by
   default. If Customize > Skills is greyed out on the work account, that's
   the cause. Check this before building anything else — it decides whether
   this plan covers four app surfaces or two.

2. **Multi-file zip upload — unverified.** A skill is a directory of
   SKILL.md plus supporting files, and that's documented for the Skills API.
   Whether claude.ai's chat upload accepts supporting files the same way is
   untested. If it does, one bundle whose SKILL.md routes to many reference
   files collapses most upload churn. Test with a two-file zip on the
   personal account before restructuring.

3. **Client-derived content stays out of GitHub.** Egress permission is not
   publishing permission, and a private repo is still infrastructure the
   employer doesn't control. Generic engineering procedures publish freely;
   pharma process detail, internal endpoints, and client specifics stay in
   company git and reach work Claude Code only.

## Rejected options

- **Cloudflare Worker / custom MCP server** — on Team and Enterprise plans
  only an organization Owner can add a custom connector, so this reaches at
  most the personal account. Also loses progressive disclosure: every tool
  description sits in context permanently instead of loading on demand.
- **`/v1/skills` API** — workspace scope, not a claude.ai chat account.
  Skills uploaded there are shared workspace-wide and run in a sandboxed
  container with no network access. Right answer only for a custom
  front-end over the Messages API.
- **Private plugin marketplace** — distribution machinery for an audience
  of one. Revisit only if Cowork or scheduled cloud sessions enter the mix.
- **Public Pages URLs** — worked technically and passed the VPN, killed by
  the privacy requirement.
- **Unlisted URL with a token** — unguessable is not private. URLs leak
  through server logs, proxy logs, and browser history.
- **Local MCP via `claude_desktop_config.json`** — uses the local network,
  desktop-only, never reaches either phone.

## Synced-skill caveat

For skills that arrive via `CLAUDE_CODE_SYNC_SKILLS`, local sessions do not
execute `!` shell injection, do not attach `@` file references, and do not
substitute `${CLAUDE_PROJECT_DIR}` — these reach the model as literal text.
Claude Code also skips a synced skill whose name collides with a local or
bundled skill, which is a usable override: keep a hand-maintained copy in
`~/.claude/skills/<name>` to suppress the synced one.
