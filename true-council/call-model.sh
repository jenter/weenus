#!/usr/bin/env bash
# call-model.sh — one council seat, one model, one call. Prints the model's
# text reply to stdout; non-zero exit on failure.
#
# Usage: call-model.sh <provider> <model> <system-prompt-file> <user-prompt-file>
#
# Providers:
#   claude-cli  - the signed-in `claude` CLI (FREE mode). <model> is a --model flag.
#   openai      - OpenAI Chat Completions.        needs OPENAI_API_KEY
#   google      - Google Gemini generateContent.  needs GEMINI_API_KEY or GOOGLE_API_KEY
#   anthropic   - Anthropic Messages API.         needs ANTHROPIC_API_KEY
#   xai         - xAI (OpenAI-compatible).        needs XAI_API_KEY
#   deepseek    - DeepSeek (OpenAI-compatible).   needs DEEPSEEK_API_KEY
#   openrouter  - OpenRouter (OpenAI-compatible). needs OPENROUTER_API_KEY
#
# openai/xai/deepseek/openrouter share one code path (OpenAI wire format);
# google and anthropic each have their own.

set -euo pipefail

[ $# -eq 4 ] || { echo "usage: $0 <provider> <model> <sys-file> <usr-file>" >&2; exit 2; }
provider=$1 model=$2 sysf=$3 usrf=$4
command -v jq >/dev/null || { echo "call-model.sh: jq is required" >&2; exit 3; }
sys=$(cat "$sysf"); usr=$(cat "$usrf")

case "$provider" in
  claude-cli)
    exec claude --model "$model" -p "$sys

$usr" < /dev/null
    ;;

  openai|xai|deepseek|openrouter)
    case "$provider" in
      openai)     url=https://api.openai.com/v1/chat/completions;   key=${OPENAI_API_KEY:?OPENAI_API_KEY not set} ;;
      xai)        url=https://api.x.ai/v1/chat/completions;          key=${XAI_API_KEY:?XAI_API_KEY not set} ;;
      deepseek)   url=https://api.deepseek.com/v1/chat/completions;  key=${DEEPSEEK_API_KEY:?DEEPSEEK_API_KEY not set} ;;
      openrouter) url=https://openrouter.ai/api/v1/chat/completions; key=${OPENROUTER_API_KEY:?OPENROUTER_API_KEY not set} ;;
    esac
    resp=$(jq -n --arg m "$model" --arg s "$sys" --arg u "$usr" \
      '{model:$m, messages:[{role:"system",content:$s},{role:"user",content:$u}]}' \
      | curl -sS --fail-with-body "$url" \
          -H "Authorization: Bearer $key" -H "Content-Type: application/json" -d @-)
    printf '%s' "$resp" | jq -e -r '.choices[0].message.content' \
      || { echo "call-model.sh: unexpected $provider response: $resp" >&2; exit 1; }
    ;;

  anthropic)
    # COUNCIL_ANTHROPIC_API_KEY is preferred so a plain ANTHROPIC_API_KEY in
    # the Claude Code env doesn't get pulled in here (and vice-versa: keep the
    # council's Anthropic key out of Claude Code's own auth path).
    key=${COUNCIL_ANTHROPIC_API_KEY:-${ANTHROPIC_API_KEY:?COUNCIL_ANTHROPIC_API_KEY (or ANTHROPIC_API_KEY) not set}}
    resp=$(jq -n --arg m "$model" --arg s "$sys" --arg u "$usr" \
      '{model:$m, max_tokens:1200, system:$s, messages:[{role:"user",content:$u}]}' \
      | curl -sS --fail-with-body https://api.anthropic.com/v1/messages \
          -H "x-api-key: $key" -H "anthropic-version: 2023-06-01" \
          -H "Content-Type: application/json" -d @-)
    printf '%s' "$resp" | jq -e -r '.content[0].text' \
      || { echo "call-model.sh: unexpected anthropic response: $resp" >&2; exit 1; }
    ;;

  google)
    key=${GEMINI_API_KEY:-${GOOGLE_API_KEY:?GEMINI_API_KEY or GOOGLE_API_KEY not set}}
    resp=$(jq -n --arg s "$sys" --arg u "$usr" \
      '{system_instruction:{parts:[{text:$s}]}, contents:[{role:"user",parts:[{text:$u}]}]}' \
      | curl -sS --fail-with-body \
          "https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${key}" \
          -H "Content-Type: application/json" -d @-)
    printf '%s' "$resp" | jq -e -r '.candidates[0].content.parts[0].text' \
      || { echo "call-model.sh: unexpected google response: $resp" >&2; exit 1; }
    ;;

  *)
    echo "call-model.sh: unknown provider '$provider'" >&2; exit 2 ;;
esac
