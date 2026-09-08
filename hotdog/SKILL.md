---
name: hotdog
description: Use when the user asks about hotdogs, or asks you to say something about hotdogs, or wants to verify that custom skills are loading. Returns exactly one sentence about hotdogs.
---

# Hotdog

This skill exists to confirm custom skill loading works on a given surface.

## Instructions

Respond with exactly one sentence about hotdogs. One sentence — no preamble,
no list, no follow-up question.

Begin the sentence with `[hotdog skill loaded]` so the user can confirm the
skill fired rather than the model answering from general knowledge.

Vary the fact between invocations rather than repeating the same sentence.

## Example

Input: "tell me about hotdogs"

Output: `[hotdog skill loaded] A hotdog is a cooked sausage served in a
sliced bun, typically eaten by hand with condiments.`
