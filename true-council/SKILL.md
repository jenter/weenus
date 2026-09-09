---
name: true-council
description: >
  Run a real question or decision through a council of 5 advisors who
  answer independently, peer-review each other anonymously, then let this
  session act as chairman and synthesize a verdict. FREE mode (default,
  no API keys) fans out to separate Claude models via `claude -p`
  subprocesses — Opus 5, Sonnet 5, Haiku 4.5. PAID mode fans
  out to real cross-vendor models (OpenAI, Google Gemini, xAI, DeepSeek,
  Anthropic, or OpenRouter) when provider API keys are present; the skill
  detects available keys and ASKS before using paid.
  MANDATORY TRIGGERS: 'true council this', 'real council this',
  'multi-model council', 'council this for real', 'run the true council'.
  STRONG TRIGGERS (only with a genuine decision that has stakes and
  multiple defensible options): 'war room this', 'pressure-test this',
  'stress-test this', 'should I X or Y', 'which option', 'is this the
  right move', 'I'm torn between', 'help me decide'. Do NOT fire on
  factual lookups, single-answer questions, casual 'should I' with no
  real tradeoff, or creative-generation tasks. Claude Code only — it
  shells out to `claude`, `curl`, and `jq`.
---

# True Council

A multi-model take on Karpathy's LLM Council. Five advisor seats, each
answered by a **different model**, so the disagreement is real model
diversity rather than one model imitating five voices. This session never
answers as a seat — it only frames the question and, at the end, acts as
chairman.

Runs in **Claude Code only**. Needs `claude` on PATH (FREE mode) or
`curl` + `jq` and at least one provider key (PAID mode). All model calls
go through the helper script next to this file:
`~/.claude/skills/true-council/call-model.sh` — read its header for the
exact provider list and required env vars.

## Step 0 — pick the mode

FREE mode is always the default. Detect whether PAID is even possible:

```bash
for v in OPENAI_API_KEY GEMINI_API_KEY GOOGLE_API_KEY \
         COUNCIL_ANTHROPIC_API_KEY ANTHROPIC_API_KEY \
         XAI_API_KEY DEEPSEEK_API_KEY OPENROUTER_API_KEY; do
  [ -n "${!v:-}" ] && echo "$v set"
done
```

- **No keys found:** run FREE mode. Mention once that a cross-vendor PAID
  mode exists if they add keys — don't nag.
- **One or more keys found:** ask the user, plainly, before running:
  *"FREE (5 Claude models, no extra cost) or PAID (cross-vendor: <list
  the providers whose keys are set>)?"* Default to FREE if they don't
  care or don't answer.

Everything from step 3 on (peer review, chairman, transcript) is
identical in both modes.

## Seat → lens map (both modes)

| Seat | Lens |
|------|------|
| 1 | **Contrarian** — hunts for flaws, fatal assumptions, the concrete way this goes wrong |
| 2 | **First-Principles** — strips the framing, asks what's really being solved, rebuilds from base facts |
| 3 | **Expansionist** — chases undervalued upside and adjacent opportunities, ignores downside |
| 4 | **Outsider** — zero domain expertise, names what's confusing or unexamined to fresh eyes |
| 5 | **Executor** — feasibility only: what happens Monday morning, what's the first concrete step |

### FREE mode: seat → provider/model

| Seat | provider | model |
|------|----------|-------|
| 1 Contrarian | `claude-cli` | `claude-opus-5` |
| 2 First-Principles | `claude-cli` | `claude-sonnet-5` |
| 3 Expansionist | `claude-cli` | `claude-opus-5` |
| 4 Outsider | `claude-cli` | `claude-haiku-4-5` |
| 5 Executor | `claude-cli` | `claude-sonnet-5` |

3 distinct models for 5 seats — Opus 5 runs seats 1 and 3, Sonnet 5 runs
seats 2 and 5. That's fine: they're independent processes with fresh
context, so there's no cross-contamination. If a model flag is rejected
by the CLI, rerun that seat with `claude-sonnet-5` (or `claude-opus-5`)
and note the substitution in the transcript.

### PAID mode: seat → provider/model

Assign each seat to a provider whose key is actually set. Preferred
mapping when all keys are present:

| Seat | provider | model |
|------|----------|-------|
| 1 Contrarian | `openai` | `gpt-5` |
| 2 First-Principles | `anthropic` | `claude-opus-4-5` |
| 3 Expansionist | `google` | `gemini-pro-latest` |
| 4 Outsider | `xai` | `grok-4` |
| 5 Executor | `deepseek` | `deepseek-reasoner` |

**Only OpenAI + Google + Anthropic keys set** (the common case here) —
spread 5 seats across 3 providers:

| Seat | provider | model |
|------|----------|-------|
| 1 Contrarian | `openai` | `gpt-5` |
| 2 First-Principles | `anthropic` | `claude-opus-4-5` |
| 3 Expansionist | `google` | `gemini-3.6-flash` |
| 4 Outsider | `openai` | `gpt-5-mini` |
| 5 Executor | `anthropic` | `claude-sonnet-4-5` |

Reuse a provider for two seats before leaving a seat unfilled. On a
free-tier Gemini key the `*-pro*` models return HTTP 429 almost
immediately — use a `gemini-*-flash` model for that seat.
`openrouter` alone can back all 5 — ids like `openai/gpt-5`,
`google/gemini-2.5-pro`, `x-ai/grok-4`, `deepseek/deepseek-r1`,
`anthropic/claude-opus-4.5`. Model names drift; if an id 404s, call the
provider's model-list endpoint, pick a current sibling, and note the
swap. The lenses never change — only the backing model does.

## Procedure

### 1. Frame the question

Skim `CLAUDE.md`, any `memory/` files, and anything the user referenced
for 2–3 pieces of context that bear on the decision. Rewrite the user's
raw input into a tight brief with four labeled parts: **Decision**,
**Context**, **Constraints**, **Stakes**. Under ~150 words. Write it to
`"$TMPDIR/council/brief.md"`.

### 2. Run the five seats in parallel

For each seat, write its system prompt to a file and its user prompt
(the lens instruction + the brief) to another, then call the helper.
Fire all five in a single message so they run concurrently:

```bash
S="$HOME/.claude/skills/true-council"
D="$TMPDIR/council"
# per seat n, with $PROVIDER and $MODEL from the table for the chosen mode:
printf '%s\n' "You are the <SEAT NAME> on an advisory council. <one-line lens description>." > "$D/sys-$n.txt"
printf '%s\n\n%s\n' "Answer ONLY from this perspective. 150-300 words. No hedging, no balance — that's another seat's job. Take a clear position." "BRIEF:
$(cat "$D/brief.md")" > "$D/usr-$n.txt"
"$S/call-model.sh" "$PROVIDER" "$MODEL" "$D/sys-$n.txt" "$D/usr-$n.txt" > "$D/seat-$n.md" 2>"$D/seat-$n.err"
```

If a seat call errors or returns empty, retry once; if it still fails,
proceed with the seats you have and note the gap. In FREE mode, a
rejected model flag falls back to `claude-sonnet-5` / `claude-opus-5`
per the note above.

### 3. Anonymized peer review

Read the five outputs. Shuffle their order and relabel them Response A–E
(keep a private note of which letter is which seat). For each seat, call
the helper again with its **same provider/model**:

> Five council members answered a question. Here are their responses,
> anonymized: [A–E]. In 120–200 words: which response is strongest and
> why, what is the biggest blind spot shared across them, and what did
> they all miss?

Write each to `"$D/review-$n.md"`. To save calls it's fine to run one
review per distinct model rather than one per seat.

### 4. Chairman synthesis (this session — no subprocess)

You are the chairman. From the five responses and the reviews, write:

- **Convergence** — what multiple seats independently agreed on (treat as
  higher-confidence signal).
- **Live disagreements** — where they genuinely clash, stated as a clash,
  not smoothed over.
- **Blind spots surfaced in review** — what the peer round caught.
- **Recommendation** — a clear call. You may overrule the majority if the
  reasoning warrants it; say so explicitly when you do.
- **Monday-morning step** — the single next concrete action.

### 5. Present in chat

Verdict as scannable markdown with those headings. Lead with the
recommendation, not the process. Keep seat-by-seat detail out unless the
user asks — offer the transcript instead. Say which mode and which
models ran.

### 6. Transcript

For a weighty decision, save the full record — brief, five seat
responses, reviews, verdict, mode, and models — to
`./council-transcripts/council-<YYYY-MM-DD-HHMM>.md` and give the user the
path. Skip it for lighter calls.

## Notes

- Where to put keys: the `env` block of `~/.claude/settings.json` (loads
  for every Claude Code session) or `export`s in `~/.zshrc`. Any subset
  works — the skill uses whatever is set. FREE mode needs no keys.
  Get keys at platform.openai.com/api-keys, aistudio.google.com/apikey,
  console.anthropic.com, or openrouter.ai/keys.
- Use `COUNCIL_ANTHROPIC_API_KEY`, not a bare `ANTHROPIC_API_KEY`, in the
  Claude Code env — a bare one can redirect Claude Code's own billing to
  that API account. `call-model.sh` reads the `COUNCIL_`-prefixed name
  first.
- Seat calls need no tools — pure reasoning. If a `claude -p` call hangs
  on a permission prompt, add `--allowedTools ''` inside `call-model.sh`.
- Never let a seat see another seat's answer before step 3.
- If neither `claude` nor a usable key is available, tell the user the
  council can't convene here rather than silently answering solo.
