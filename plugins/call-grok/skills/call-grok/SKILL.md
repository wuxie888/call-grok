---
name: call-grok
description: Call Grok only when its distinctive capability is useful, while Codex remains the coordinator. Use when a user says to call, use, ask, install, configure, log in to, or troubleshoot Grok/Grok CLI; when X/Twitter-native intelligence is needed; or when a confirmed Grok Imagine video execution should be handed off. Detect a missing CLI, guide an authorized user-level install and OAuth login, preserve the original request, and resume it through grok-x or grok-video. The memorable user-facing idea is "快请 Grok".
---

# 快请 Grok

Keep Codex as the planner, verifier, and final deliverer. Use Grok only for its distinct X-native retrieval, an explicitly requested independent opinion, or confirmed Imagine video execution.

## Preserve the request

Before setup, retain the user's original goal and inputs. Setup is an interruption, not the deliverable. After readiness is restored, resume the original task automatically.

## Run the local preflight

### Select the native runner

- On native Windows PowerShell, use the `.ps1` runner. Do not route through Git Bash merely because it is installed.
- On macOS, Linux, WSL, or an explicitly selected Bash environment, use the `.sh` runner.
- Native Windows has offline PowerShell CI coverage. Live Grok OAuth, X retrieval, and Imagine media remain unverified on Windows, so preserve that evidence boundary.

Resolve this Skill's directory at runtime and run:

```bash
scripts/grok-bootstrap.sh check --capability core
```

```powershell
& scripts/grok-bootstrap.ps1 -Action Check -Capability core
```

Use `--capability x` for X work and `--capability video` for video work. Read [references/runtime-contract.md](references/runtime-contract.md) when handling a non-ready status.

The preflight never reads or prints `~/.grok/auth.json`. Treat `auth=unknown` as intentional: local checks cannot reliably prove remote OAuth readiness, and `grok models` is not an authoritative authentication probe. The first-party installer may internally use xAI's own cached credential store; the Skill must never inspect or expose it.

## Bootstrap a missing installation

If the user explicitly requested installation/configuration, or approves after seeing the install target, run:

```bash
scripts/grok-bootstrap.sh install --approved
```

```powershell
& scripts/grok-bootstrap.ps1 -Action Install -Approved
```

Otherwise state that the official installer will install the stable CLI under `~/.grok/bin` and ask once for permission. Do not install from an unofficial mirror, request an API key, enable billing, or require administrator access by default.

After installation, start login:

```bash
scripts/grok-bootstrap.sh login --approved --oauth
```

```powershell
& scripts/grok-bootstrap.ps1 -Action Login -Approved -LoginMode oauth
```

Use `--device-auth` only for a remote or headless machine. The Skill may open the authorization flow and wait, but the user must inspect the account and perform the final browser/device approval. Never click account authorization on the user's behalf.

Successful `grok login` means the login flow completed; the first bounded task is the practical authentication check. If it returns an explicit authentication error, offer login again and do not inspect credential files.

## Route the original task

- Route X posts, accounts, threads, discourse, launches, rumors, or sentiment to `$grok-x`.
- Route an explicitly confirmed image-to-video execution to `$grok-video`.
- Keep research synthesis, source verification, creative direction, scripts, storyboards, motion design, prompts, asset preparation, QA, and delivery in Codex.
- Keep ordinary coding, general web research, image generation/editing, TTS/STT, and realtime voice in Codex unless the user specifically asks for Grok.

Do not ask the user to remember commands or select a child Skill. Route automatically and return to the original request after setup.

## Safety boundaries

- Do not read, print, copy, serialize, or persist Grok credential files.
- Do not auto-update a working CLI; `grok update --check --json` may be used read-only.
- Do not generate, edit, extend, or retry video until the user confirms the exact duration, resolution, inputs, expected quota/cost impact, and one-call action.
- Do not change Opt in/Opt out, ZDR, storage, billing, or account settings without explicit authorization.
- Do not post, reply, like, follow, upload unrelated files, or mutate X.
