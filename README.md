# codex-imagegen

**Route OpenClaw (or any agentic tool that can shell out) image generation through your ChatGPT Pro/Plus subscription instead of the OpenAI API.**

Wraps Codex CLI's built-in `$imagegen` skill so `gpt-image-2` runs bill against your Codex subscription credits — not your OpenAI API key. If you already pay for ChatGPT Pro ($200/mo) or Plus ($20/mo), this turns that subscription into the image generator your agents already wanted.

---

## Why this exists

OpenClaw's native `image_generate` tool resolves to `api.openai.com` and requires a paid API key. If you already have a ChatGPT subscription you're effectively paying twice — once for the plan, again per image. Codex CLI has `$imagegen` baked in but it's behind a feature flag marked "under development," and no third-party framework surfaces it by default. This skill closes that gap.

## Requirements

- [Codex CLI](https://developers.openai.com/codex/cli) installed and signed in with your ChatGPT Pro/Plus account (`codex login`)
- `bash` available (Git Bash on Windows, native on macOS/Linux)
- Any agentic framework that can invoke shell scripts (OpenClaw, Claude Code, custom agents, etc.)

## Install

1. Copy the `codex-imagegen/` folder into your workspace's skills directory.
   For OpenClaw: `<workspace>/skills/codex-imagegen/`.
2. Make the bash script executable (macOS/Linux):
   ```
   chmod +x codex-imagegen/scripts/imagegen.sh
   ```
3. Enable the Codex image feature flag (one-time — persists in `~/.codex/config.toml`):
   ```
   codex features enable image_generation
   ```
4. Point your agent at it. For OpenClaw, add to `TOOLS.md`:
   > **Image generation:** always use `bash skills/codex-imagegen/scripts/imagegen.sh`. Never call the built-in `image_generate` tool — that hits the paid API path.
5. (Recommended) Add a matching hard rule to `AGENTS.md` so every new session boot reinforces it.

## Usage

```bash
bash codex-imagegen/scripts/imagegen.sh \
  --prompt "cinematic cat astronaut on a red dune at sunset" \
  --size 1024x1024 \
  --quality medium \
  --out /absolute/path/output.png
```

- `--size`: `1024x1024` | `1024x1536` (portrait) | `1536x1024` (landscape) | `2000x2000`
- `--quality`: `low` | `medium` (default) | `high` — high burns credits ~3–5× faster
- `--ref <path>`: repeatable; passes the image to `codex exec -i` as a style/identity anchor
- Stdout on success = the final PNG path
- Default output dir = `<skill-dir>/output/`; override with `$CODEX_IMAGEGEN_OUT_DIR` or `--out`

## Caveats (honest)

- The `image_generation` feature flag is still marked "under development" in Codex CLI. It works today; could change in a future release.
- Subscription-billed image generation burns Codex credits 3–5× faster than a text turn. ChatGPT Pro has a 10× Codex multiplier through May 31, 2026 — substantial headroom but not unlimited.
- **No video support.** Codex CLI has no `$videogen`. Use `sora.com` manually (Pro = unlimited) or the paid `sora-2` API.
- OpenAI could remove subscription access for this path at any time. Bet on it accordingly.

## Troubleshooting

- **"image_generation feature disabled"**: `codex features enable image_generation`, retry.
- **"no PNG found in thread dir"**: the inner Codex turn didn't invoke `$imagegen`. Prefix your prompt with `Use the $imagegen skill to generate:` to force it.
- **Windows sandbox `-1073741502` errors**: cosmetic noise from the inner Codex session's shell attempts. Doesn't block image generation; the wrapper ignores them.
- **Want to fall back to the API path?** Set `OPENAI_API_KEY` and your framework's built-in image tool will still work. They're independent paths.

## License

MIT. See [LICENSE](LICENSE).

## Contributing

Issues and PRs welcome. Especially:
- macOS / Linux install verifications (Windows is the primary tested path)
- Support for other agent frameworks beyond OpenClaw (wrappers, adapters)
- Reference-image fidelity improvements if you figure out better `$imagegen` prompting

---

*Built while trying to stop hemorrhaging API dollars on an automated NFT content pipeline. If you're doing something similar and find another gap like this, tell me.*
