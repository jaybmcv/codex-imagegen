---
name: codex-imagegen
description: Generate images via Codex CLI's built-in $imagegen — bills ChatGPT Pro subscription credits, not the OpenAI API.
homepage: https://developers.openai.com/codex/cli/features
metadata: {"clawdbot":{"emoji":"🖼️","requires":{"bins":["codex"]}}}
---

# Codex $imagegen (subscription-billed)

Generates images with `gpt-image-2` through Codex CLI's built-in image skill.
**Billing:** counts against ChatGPT Pro Codex usage (10× multiplier through May 31, 2026). Does NOT touch the OpenAI API key or API credits.

## When to use this

- Any time you'd reach for `image_generate` / the `openai/*` image path — use this instead.
- Marketing images, mockups, concept art, thumbnails, avatars, etc.

## One-time setup

```
codex features enable image_generation
```

The `image_generation` feature is flagged "under development" in Codex CLI 0.118.0 but works. Re-run this if the flag gets reset after a Codex CLI update.

## Usage

```
bash <skill-dir>/scripts/imagegen.sh \
  --prompt "cinematic cat astronaut on a red dune at sunset" \
  --size 1024x1024 \
  --quality medium \
  --out /absolute/path/to/output.png
```

Windows cmd/PowerShell wrapper (requires Git Bash):
```
<skill-dir>\scripts\imagegen.cmd --prompt "..." --out C:\path\to\output.png
```

### Arguments

| Flag        | Required | Default                           | Notes                                    |
|-------------|----------|-----------------------------------|------------------------------------------|
| `--prompt`  | yes      | —                                 | Natural-language description             |
| `--size`    | no       | `1024x1024`                       | Also: `1024x1536`, `1536x1024`, `2000x2000` |
| `--quality` | no       | `medium`                          | `low` \| `medium` \| `high`              |
| `--out`     | no       | `<skill-dir>/output/codex-img-<ts>.png` | Absolute path recommended. Override default dir via `$CODEX_IMAGEGEN_OUT_DIR`. |
| `--ref`     | no       | —                                 | Reference image path; repeatable. Attached via `codex exec -i` for style/identity conditioning (fidelity unverified — pilot only). |

### Output

Script prints a single line to stdout: the absolute path of the saved PNG.
Non-zero exit code = failure; read stderr for reason.

## Billing impact

Per OpenAI docs: built-in image generation counts toward Codex usage limits and consumes included limits **3–5× faster** than a normal turn depending on quality. At ChatGPT Pro with the 10× multiplier you still have substantial headroom; keep quality at `medium` unless a marketing asset genuinely needs `high`.

## How it works (so agents know)

1. Wrapper runs `codex exec --ephemeral --json` with a prompt that invokes `$imagegen`.
2. First JSONL event is `{"type":"thread.started","thread_id":"..."}` — wrapper captures that id.
3. Codex writes the PNG to `~/.codex/generated_images/<thread_id>/`. The file has been named `ig_*.png` and, as observed on codex-cli 0.162.1, `exec-*.png`.
4. Wrapper copies the newest PNG out of that dir to `--out`.
5. Temporary thread directory is left in place (cheap, <100KB) — `~/.codex/generated_images` can be cleared periodically.

## Troubleshooting

- **"image_generation feature disabled"**: `codex features enable image_generation`, then retry.
- **"no PNG found in thread dir"**: the inner Codex turn didn't call `$imagegen` — usually means the prompt got reinterpreted. Prefix your prompt with `Use the $imagegen skill to generate:` to be explicit.
- **Long turns / Windows sandbox -1073741502 errors**: those are Codex sandbox noise from unrelated shell calls inside the inner session. They don't block image generation — the wrapper ignores them.
- **Want the legacy API-billed path?** Set `OPENAI_API_KEY` and use the OpenClaw built-in `image_generate` tool instead. This skill will still work; they're independent paths.

## Limits

- Does not cover **video generation**. Codex CLI has no `$videogen` equivalent as of 0.118.0. For video, use `sora.com` directly (Pro subscription covers unlimited), or the paid `sora-2` API.
