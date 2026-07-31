# Runtime contract

`grok-bootstrap.sh check` emits one JSON object and uses these states:

| Status | Meaning | Required response |
|---|---|---|
| `ready_local` | CLI and task-local dependencies are present | Route the preserved request |
| `missing_cli` | No executable was found on PATH or at `~/.grok/bin/grok` | Ask once to install, unless installation was already explicitly requested |
| `broken_cli` | An executable exists but `--version` fails | Explain the failure and offer an approved stable reinstall |
| `missing_dependency` | CLI exists but local task tooling is absent | Name the missing commands and ask before installing them |
| `unsupported_platform` | The official installer does not support the OS/architecture | Stop and give the detected platform; do not improvise a binary source |

`auth` remains `unknown` during local preflight. Do not reinterpret it as logged out. Complete `grok login` when requested, then let the first bounded original task reveal a real authentication error if one remains.

Installation and login are separate authority gates:

- Installation changes local files and shell PATH. It requires an explicit install/configure request or approval.
- Login opens an OAuth/device flow. The Skill may launch and wait, but the user performs final authorization.
- A video request has a separate paid-action confirmation gate even after installation and login.

If a child Skill is invoked directly, it must still perform its own local availability check and hand missing-CLI recovery back to this bootstrap flow.
