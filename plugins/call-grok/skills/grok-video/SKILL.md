---
name: grok-video
description: Execute and verify an explicitly confirmed Grok Imagine image-to-video request through Grok CLI while Codex retains creative control. Use when the user specifically wants Grok/Imagine video generation from a prepared source image, including a confirmed test or final shot. Enforce exact duration, resolution, input, quota/cost disclosure, one-call/no-retry behavior, local artifact collection, ffprobe validation, hashes, and sampled-frame QA. Do not use for ordinary image work or unconfirmed paid generation.
---

# 快请 Grok · 视频

Use Grok only as the video renderer. Keep concept, script, storyboard, camera direction, motion design, prompt writing, source-image preparation, QA, and delivery in Codex.

## Prepare without spending quota

1. Select the native runner: `.ps1` on Windows PowerShell, `.sh` on macOS/Linux/WSL/Bash. Native Windows has offline PowerShell CI coverage, but live Grok OAuth and Imagine generation remain unverified there.
2. Resolve this Skill's directory at runtime.
3. Run the Grok preflight when available:

   ```bash
   ../call-grok/scripts/grok-bootstrap.sh check --capability video
   ```

   ```powershell
   & ../call-grok/scripts/grok-bootstrap.ps1 -Action Check -Capability video
   ```

4. If Grok is missing, invoke `$call-grok` to install and log in, then resume this task.
5. Inspect the source image and verify its absolute path, aspect ratio, identity, and intended first frame.
6. Produce the final motion prompt in Codex. Do not ask Grok to plan shots or create the source image.

The tested first version supports one `image_to_video` call with duration `6` or `10` seconds and resolution `480p` or `720p`. Do not claim untested edit, extend, reference-to-video, or text-to-video support.

## Obtain the paid-action confirmation

Immediately before generation, state:

- exact source-image path;
- final prompt or a precise prompt summary;
- duration and resolution;
- that exactly one Grok Imagine call will run;
- expected weekly-quota or API-cost impact, including uncertainty;
- that failure will not be retried automatically.

Wait for explicit confirmation of that action. Installation/login approval is not video approval, and a previous video approval does not authorize a new generation.

## Execute once

After confirmation, run:

```bash
scripts/run-video.sh \
  --image "/absolute/path/source.png" \
  --prompt-file "/absolute/path/final-prompt.txt" \
  --duration 6 \
  --resolution 480p \
  --output-dir "/absolute/path/output" \
  --confirmed
```

```powershell
& scripts/run-video.ps1 `
  -Image "C:\absolute\path\source.png" `
  -PromptFile "C:\absolute\path\final-prompt.txt" `
  -Duration 6 `
  -Resolution 480p `
  -OutputDir "C:\absolute\path\output" `
  -Confirmed
```

The script restricts Grok to `image_to_video`, makes one tool call, disables retries, copies the resulting MP4 into the requested output directory, runs `ffprobe`, hashes it, and extracts three QA frames.

## Accept the artifact

Read [references/acceptance.md](references/acceptance.md). Inspect the actual MP4 metadata and sampled frames. Report generation success separately from creative acceptance.

If the CLI returns a Zero Data Retention error requiring `output.upload_url`, stop. Explain the two user-controlled choices—Opt in for direct CLI output, or configure owned R2/S3 output for Opt out—and do not change privacy or storage settings or retry.

## Boundaries

- Never pass `--confirmed` without explicit approval for the exact call.
- Never retry a failed or weak generation without a new confirmation.
- Never generate auxiliary Grok images or audio during this workflow.
- Never read or expose Grok credentials.
- Never infer remaining quota from `total_cost_usd`; use Grok `/usage` when an authoritative quota check is needed.
- Never describe a session-relative path as delivered until the file is copied into the user's output directory and verified.
