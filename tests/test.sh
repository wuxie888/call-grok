#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN="$ROOT/plugins/call-grok"
TMP_TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/call-grok-tests.XXXXXX")"

cleanup() {
  if [[ -d "$TMP_TEST_DIR" && "$TMP_TEST_DIR" == *"call-grok-tests."* ]]; then
    rm -rf -- "$TMP_TEST_DIR"
  fi
}
trap cleanup EXIT

pass() {
  printf '✓ %s\n' "$1"
}

fail() {
  printf '✗ %s\n' "$1" >&2
  exit 1
}

for command in bash node python3; do
  command -v "$command" >/dev/null 2>&1 || fail "$command is required"
done

python3 - "$ROOT/.agents/plugins/marketplace.json" "$PLUGIN/.codex-plugin/plugin.json" <<'PY'
import json
import pathlib
import sys

marketplace_path = pathlib.Path(sys.argv[1])
plugin_path = pathlib.Path(sys.argv[2])
marketplace = json.loads(marketplace_path.read_text())
plugin = json.loads(plugin_path.read_text())

assert marketplace["name"] == "call-grok"
entry = marketplace["plugins"][0]
assert entry["name"] == "call-grok"
assert entry["source"]["path"] == "./plugins/call-grok"
assert entry["policy"] == {"installation": "AVAILABLE", "authentication": "ON_USE"}
assert plugin["name"] == "call-grok"
assert plugin["version"] == "1.0.0"
assert plugin["skills"] == "./skills/"
assert plugin["license"] == "MIT"
PY
pass "marketplace and plugin manifests"

for skill in call-grok grok-x grok-video; do
  skill_file="$PLUGIN/skills/$skill/SKILL.md"
  [[ -f "$skill_file" ]] || fail "missing $skill_file"
  python3 - "$skill_file" "$skill" <<'PY'
import pathlib
import re
import sys

text = pathlib.Path(sys.argv[1]).read_text()
name = sys.argv[2]
match = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
assert match, "missing YAML frontmatter"
assert re.search(rf"^name:\s*{re.escape(name)}\s*$", match.group(1), re.MULTILINE)
assert re.search(r"^description:\s*\S", match.group(1), re.MULTILINE)
PY
done
pass "skill frontmatter and folder names"

while IFS= read -r script; do
  bash -n "$script"
done < <(find "$PLUGIN/skills" -type f -name '*.sh' -print)
node --check "$PLUGIN/skills/grok-x/scripts/extract-final-json.mjs" >/dev/null
pass "shell and Node syntax"

set +e
HOME="$TMP_TEST_DIR/home" PATH="/usr/bin:/bin" \
  "$PLUGIN/skills/call-grok/scripts/grok-bootstrap.sh" check --capability core \
  >"$TMP_TEST_DIR/bootstrap.json"
bootstrap_status=$?
set -e
[[ $bootstrap_status -eq 10 ]] || fail "missing-CLI preflight returned $bootstrap_status instead of 10"
python3 - "$TMP_TEST_DIR/bootstrap.json" <<'PY'
import json
import pathlib
import sys

result = json.loads(pathlib.Path(sys.argv[1]).read_text())
assert result["status"] == "missing_cli"
assert result["auth"] == "unknown"
assert result["path"] == ""
PY
pass "missing-CLI preflight without credential access"

set +e
"$PLUGIN/skills/grok-video/scripts/run-video.sh" >"$TMP_TEST_DIR/video.out" 2>"$TMP_TEST_DIR/video.err"
video_status=$?
set -e
[[ $video_status -eq 3 ]] || fail "unconfirmed video call returned $video_status instead of 3"
grep -Fq -- "requires --confirmed" "$TMP_TEST_DIR/video.err" || fail "missing confirmation-gate error"
pass "video paid-action confirmation gate"

node "$PLUGIN/skills/grok-x/scripts/extract-final-json.mjs" \
  <"$ROOT/tests/fixtures/grok-structured-output-recovery.json" \
  | node "$ROOT/tests/assert-recovery.mjs"
pass "structured-output recovery regression"

privacy_pattern='/Users/(myfuture|vibecoding)|/home/[^/]+|BEGIN (RSA |OPENSSH )?PRIVATE KEY|[A-Za-z0-9_]*(API_KEY|TOKEN|SECRET|PASSWORD)='
if command -v rg >/dev/null 2>&1; then
  privacy_scan=(rg -n --hidden --glob '!README*' --glob '!SECURITY.md' --glob '!test.sh' "$privacy_pattern" "$ROOT")
else
  privacy_scan=(grep -RInE --exclude='README*' --exclude='SECURITY.md' --exclude='test.sh' --exclude-dir='.git' "$privacy_pattern" "$ROOT")
fi
if "${privacy_scan[@]}" >"$TMP_TEST_DIR/privacy.txt"; then
  cat "$TMP_TEST_DIR/privacy.txt" >&2
  fail "private paths or secrets found"
fi
pass "public-repository privacy scan"

printf '\nAll local tests passed. No Grok login, X search, or media generation was performed.\n'
