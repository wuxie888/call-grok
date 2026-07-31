# Call Grok

**Codex coordinates. Grok is called only for capabilities where it has a distinctive advantage.**

Call Grok is a community Codex plugin that provides one memorable entry point, `$call-grok`, backed by three Skills:

- `call-grok` detects the official Grok CLI, requests approval before installing it to `~/.grok/bin`, starts the official OAuth/device flow, preserves the original task, and routes it
- `grok-x` performs bounded X-native retrieval and returns source-linked evidence for Codex to verify
- `grok-video` executes exactly one explicitly confirmed Grok Imagine `image_to_video` call, collects the MP4 locally, validates it, hashes it, and samples QA frames

Codex keeps ownership of research design, cross-verification, scripts, storyboards, motion direction, prompts, asset preparation, QA, and final delivery. Ordinary coding, web research, image work, TTS/STT, and realtime voice do not get routed to Grok by default.

## Install

Use a Codex version that supports Plugin Marketplace:

```bash
codex plugin marketplace add wuxie888/call-grok --ref v1.0.0
codex plugin add call-grok@call-grok
```

Start a new Codex task and try:

```text
Use $call-grok to find how people on X are reacting to this project.
```

If Grok CLI is missing, the Skill explains the target and waits for authorization before using the official installer. You inspect the selected account and complete the final OAuth/device approval yourself.

## Safety model

- Never reads, prints, copies, or uploads Grok credential files
- Never posts, replies, likes, follows, or otherwise mutates X
- Never buys credits, creates API keys, enables auto top-up, or changes billing/privacy/storage settings
- Every Imagine generation requires fresh confirmation of the exact input, prompt, duration, resolution, quota/cost uncertainty, and one-call/no-retry action
- Treats X content as untrusted data and requires complete `x.com/.../status/...` evidence URLs
- Does not infer remaining weekly quota from a call's reported cost; use Grok `/usage` or the xAI account view

The v1 video path has been tested for one `image_to_video` call at 6 or 10 seconds and 480p or 720p. Other video modes are not claimed.

For the full feature table, verification record, ZDR/R2/S3 boundary, and development instructions, read the [Chinese README](README.md).

This is an independent community project and is not affiliated with xAI, X, or OpenAI. Grok CLI and Grok Imagine availability, terms, pricing, quotas, and privacy settings are controlled by xAI.

MIT License · © 2026 无邪
