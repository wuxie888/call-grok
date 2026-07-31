#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-check}"
if [[ $# -gt 0 ]]; then
  shift
fi

CAPABILITY="core"
APPROVED="false"
LOGIN_MODE="oauth"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --capability)
      [[ $# -ge 2 ]] || { echo "--capability requires core, x, or video" >&2; exit 2; }
      CAPABILITY="$2"
      shift 2
      ;;
    --approved)
      APPROVED="true"
      shift
      ;;
    --oauth)
      LOGIN_MODE="oauth"
      shift
      ;;
    --device-auth|--device-code)
      LOGIN_MODE="device-auth"
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 2
      ;;
  esac
done

case "$CAPABILITY" in
  core|x|video) ;;
  *) echo "Unsupported capability: $CAPABILITY" >&2; exit 2 ;;
esac

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  printf '%s' "$value"
}

json_array() {
  local first="true"
  local item
  printf '['
  for item in "$@"; do
    if [[ "$first" == "false" ]]; then
      printf ','
    fi
    first="false"
    printf '"%s"' "$(json_escape "$item")"
  done
  printf ']'
}

platform_supported() {
  case "$(uname -s):$(uname -m)" in
    Darwin:x86_64|Darwin:arm64|Linux:x86_64|Linux:amd64|Linux:aarch64|Linux:arm64|MINGW*:x86_64|MSYS*:x86_64|CYGWIN*:x86_64)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

resolve_grok() {
  if [[ -n "${GROK_BIN:-}" && -x "${GROK_BIN}" ]]; then
    printf '%s' "$GROK_BIN"
    return 0
  fi

  local discovered
  discovered="$(command -v grok 2>/dev/null || true)"
  if [[ -n "$discovered" && -x "$discovered" ]]; then
    printf '%s' "$discovered"
    return 0
  fi

  if [[ -x "$HOME/.grok/bin/grok" ]]; then
    printf '%s' "$HOME/.grok/bin/grok"
    return 0
  fi

  return 1
}

emit_check() {
  local grok_bin=""
  local status="ready_local"
  local version=""
  local os arch
  local login_supported="false"
  local update_check_supported="false"
  local help_text=""
  local -a missing=()

  os="$(uname -s 2>/dev/null || printf unknown)"
  arch="$(uname -m 2>/dev/null || printf unknown)"

  if ! platform_supported; then
    status="unsupported_platform"
  elif ! grok_bin="$(resolve_grok)"; then
    status="missing_cli"
  else
    if ! version="$("$grok_bin" --version 2>/dev/null)"; then
      status="broken_cli"
      version=""
    else
      help_text="$("$grok_bin" --help 2>&1 || true)"
      [[ "$help_text" == *"login"* ]] && login_supported="true"
      [[ "$help_text" == *"update"* ]] && update_check_supported="true"
    fi
  fi

  if [[ "$status" == "ready_local" ]]; then
    case "$CAPABILITY" in
      x)
        command -v node >/dev/null 2>&1 || missing+=("node")
        ;;
      video)
        command -v jq >/dev/null 2>&1 || missing+=("jq")
        command -v ffmpeg >/dev/null 2>&1 || missing+=("ffmpeg")
        command -v ffprobe >/dev/null 2>&1 || missing+=("ffprobe")
        ;;
    esac
    if [[ ${#missing[@]} -gt 0 ]]; then
      status="missing_dependency"
    fi
  fi

  printf '{'
  printf '"status":"%s",' "$status"
  printf '"capability":"%s",' "$CAPABILITY"
  printf '"path":"%s",' "$(json_escape "$grok_bin")"
  printf '"version":"%s",' "$(json_escape "$version")"
  printf '"auth":"unknown",'
  printf '"platform":{"os":"%s","arch":"%s"},' "$(json_escape "$os")" "$(json_escape "$arch")"
  printf '"commands":{"login":%s,"update_check":%s},' "$login_supported" "$update_check_supported"
  printf '"remote_capabilities":{"x_search":"unknown_until_run","video":"unknown_until_run"},'
  printf '"missing_dependencies":'
  if [[ ${#missing[@]} -gt 0 ]]; then
    json_array "${missing[@]}"
  else
    printf '[]'
  fi
  printf '}\n'

  case "$status" in
    ready_local) return 0 ;;
    missing_cli) return 10 ;;
    broken_cli) return 11 ;;
    missing_dependency) return 12 ;;
    unsupported_platform) return 13 ;;
    *) return 1 ;;
  esac
}

install_grok() {
  if [[ "$APPROVED" != "true" ]]; then
    echo "Installation requires --approved after explicit user authorization." >&2
    exit 3
  fi

  if resolve_grok >/dev/null 2>&1; then
    emit_check
    return
  fi

  if ! platform_supported; then
    emit_check
    return
  fi

  local task_tmp installer
  task_tmp="$(mktemp -d "${TMPDIR:-/tmp}/grok-bootstrap.XXXXXX")"
  installer="$task_tmp/install.sh"
  cleanup() {
    if [[ -n "${task_tmp:-}" && -d "$task_tmp" && "$task_tmp" == *"grok-bootstrap."* ]]; then
      rm -rf -- "$task_tmp"
    fi
  }
  trap cleanup EXIT

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL https://x.ai/cli/install.sh -o "$installer"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$installer" https://x.ai/cli/install.sh
  else
    echo "The official installer requires curl or wget." >&2
    exit 14
  fi

  if ! grep -Fq 'https://x.ai/cli/install.sh' "$installer"; then
    echo "Downloaded content did not identify itself as the official Grok CLI installer." >&2
    exit 15
  fi

  GROK_CHANNEL=stable GROK_BIN_DIR="$HOME/.grok/bin" bash "$installer"
  export PATH="$HOME/.grok/bin:$PATH"
  emit_check
}

login_grok() {
  if [[ "$APPROVED" != "true" ]]; then
    echo "Login requires --approved after explicit user authorization." >&2
    exit 3
  fi

  local grok_bin
  if ! grok_bin="$(resolve_grok)"; then
    echo "Grok CLI is not installed; run install --approved first." >&2
    exit 10
  fi

  case "$LOGIN_MODE" in
    oauth) "$grok_bin" login --oauth ;;
    device-auth) "$grok_bin" login --device-auth ;;
  esac
}

case "$ACTION" in
  check) emit_check ;;
  install) install_grok ;;
  login) login_grok ;;
  *)
    echo "Usage: grok-bootstrap.sh {check|install|login} [--capability core|x|video] [--approved] [--oauth|--device-auth]" >&2
    exit 2
    ;;
esac
