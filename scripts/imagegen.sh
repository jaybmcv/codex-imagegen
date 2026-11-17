#!/usr/bin/env bash
# codex-imagegen wrapper — generates an image via Codex CLI's $imagegen skill,
# billed against the ChatGPT Pro subscription (not the OpenAI API).
#
# Usage:
#   imagegen.sh --prompt "..." [--size 1024x1024] [--quality medium]
#               [--out path.png] [--ref path1 [--ref path2 ...]]
#
# --ref: reference image(s) attached via `codex exec -i`. Used by $imagegen
#        for style/identity conditioning (unverified fidelity — pilot only).
#
# Exit 0 on success; prints the final PNG path on stdout.
# Exit non-zero on failure; human-readable reason on stderr.

set -euo pipefail

PROMPT=""
SIZE="1024x1024"
QUALITY="medium"
OUT=""
REFS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt)  PROMPT="$2"; shift 2 ;;
    --size)    SIZE="$2"; shift 2 ;;
    --quality) QUALITY="$2"; shift 2 ;;
    --out)     OUT="$2"; shift 2 ;;
    --ref)     REFS+=("$2"); shift 2 ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$PROMPT" ]]; then
  echo "error: --prompt is required" >&2
  exit 2
fi

case "$QUALITY" in low|medium|high) ;; *) echo "error: --quality must be low|medium|high" >&2; exit 2 ;; esac

# Default output = <skill-dir>/output/codex-img-<ts>.png — portable across installs.
# Override via --out (absolute path recommended) or $CODEX_IMAGEGEN_OUT_DIR env var.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
if [[ -z "$OUT" ]]; then
  TS="$(date +%Y%m%d-%H%M%S)"
  DEFAULT_OUT_DIR="${CODEX_IMAGEGEN_OUT_DIR:-$SKILL_DIR/output}"
  OUT="$DEFAULT_OUT_DIR/codex-img-$TS.png"
fi

OUT_DIR="$(dirname "$OUT")"
mkdir -p "$OUT_DIR"

TMP_CWD="$(mktemp -d -t codex-imagegen-XXXXXX)"
trap 'rm -rf "$TMP_CWD"' EXIT

JSONL="$TMP_CWD/events.jsonl"

# Build the inner prompt — explicit to avoid the agent reinterpreting the request.
REF_HINT=""
if [[ ${#REFS[@]} -gt 0 ]]; then
  REF_HINT="

Reference images have been attached to this turn (${#REFS[@]} total). Pass them to \$imagegen as style/identity anchors so the generated image matches their visual language (palette, lighting, character design, rendering style). Do NOT describe the characters in the subjects from the references in your text prompt — let the reference images carry identity; your text should describe the scene/action only."
fi

INNER_PROMPT="Use the \$imagegen skill to generate this image: ${PROMPT}

Parameters: size ${SIZE}, quality ${QUALITY}.${REF_HINT}

Rules:
- Use ONLY the built-in \$imagegen skill. Do NOT use curl, the API, or any shell command.
- Do NOT attempt to move, copy, or verify the file. The caller handles that externally.
- After generation, end the turn. No follow-up actions."

REF_ARGS=()
for r in "${REFS[@]}"; do
  if [[ ! -f "$r" ]]; then
    echo "[imagegen] reference not found: $r" >&2
    exit 2
  fi
  REF_ARGS+=(--image "$r")
done

echo "[imagegen] invoking codex exec (size=$SIZE quality=$QUALITY refs=${#REFS[@]})..." >&2

# Feed the prompt via stdin to avoid any Windows cmd.exe argument quoting issues.
# --sandbox read-only keeps the inner agent from attempting file ops that fail on Windows sandbox.
printf '%s' "$INNER_PROMPT" | codex exec \
  --ephemeral \
  --skip-git-repo-check \
  --sandbox read-only \
  --json \
  "${REF_ARGS[@]}" \
  - \
  >"$JSONL" 2>"$TMP_CWD/stderr.log" || {
    echo "[imagegen] codex exec failed; stderr follows:" >&2
    tail -40 "$TMP_CWD/stderr.log" >&2 || true
    exit 1
  }

# Extract thread_id from the first thread.started event.
THREAD_ID="$(grep -m1 '"thread.started"' "$JSONL" | sed -E 's/.*"thread_id":"([^"]+)".*/\1/')"
if [[ -z "$THREAD_ID" ]]; then
  echo "[imagegen] could not find thread_id in codex output" >&2
  echo "[imagegen] first 20 events:" >&2
  head -20 "$JSONL" >&2
  exit 3
fi

CODEX_IMG_DIR="${USERPROFILE:-$HOME}/.codex/generated_images/$THREAD_ID"
# On Git Bash $USERPROFILE comes through as C:\Users\...; normalize slashes.
CODEX_IMG_DIR="${CODEX_IMG_DIR//\\/\/}"

if [[ ! -d "$CODEX_IMG_DIR" ]]; then
  echo "[imagegen] generated_images dir not found: $CODEX_IMG_DIR" >&2
  echo "[imagegen] this usually means codex did not invoke \$imagegen. Recent agent messages:" >&2
  grep '"type":"agent_message"' "$JSONL" | tail -5 >&2 || true
  exit 4
fi

# Grab the newest PNG in the thread dir. Codex has named these ig_*.png and,
# as observed on codex-cli 0.162.1, exec-*.png, so match any PNG.
SRC_PNG="$(ls -1t "$CODEX_IMG_DIR"/*.png 2>/dev/null | head -1 || true)"
if [[ -z "$SRC_PNG" ]]; then
  echo "[imagegen] no PNG found in thread dir: $CODEX_IMG_DIR" >&2
  ls -la "$CODEX_IMG_DIR" >&2 || true
  exit 5
fi

cp -f "$SRC_PNG" "$OUT"
echo "[imagegen] saved: $OUT ($(stat -c %s "$OUT" 2>/dev/null || wc -c <"$OUT") bytes)" >&2
echo "$OUT"
