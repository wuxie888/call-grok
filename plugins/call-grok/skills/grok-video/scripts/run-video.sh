#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
IMAGE=""
PROMPT=""
PROMPT_FILE=""
DURATION=""
RESOLUTION=""
OUTPUT_DIR=""
CONFIRMED="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image) IMAGE="${2:-}"; shift 2 ;;
    --prompt) PROMPT="${2:-}"; shift 2 ;;
    --prompt-file) PROMPT_FILE="${2:-}"; shift 2 ;;
    --duration) DURATION="${2:-}"; shift 2 ;;
    --resolution) RESOLUTION="${2:-}"; shift 2 ;;
    --output-dir) OUTPUT_DIR="${2:-}"; shift 2 ;;
    --confirmed) CONFIRMED="true"; shift ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

if [[ "$CONFIRMED" != "true" ]]; then
  echo "Video generation requires --confirmed after explicit approval of the exact paid action." >&2
  exit 3
fi

if [[ -z "$IMAGE" || ! -f "$IMAGE" || ! -r "$IMAGE" ]]; then
  echo "--image must point to a readable source image." >&2
  exit 2
fi

if [[ -n "$PROMPT" && -n "$PROMPT_FILE" ]]; then
  echo "Use either --prompt or --prompt-file, not both." >&2
  exit 2
fi

if [[ -n "$PROMPT_FILE" ]]; then
  [[ -f "$PROMPT_FILE" && -r "$PROMPT_FILE" ]] || { echo "--prompt-file must be readable." >&2; exit 2; }
  PROMPT="$(<"$PROMPT_FILE")"
fi

if [[ -z "${PROMPT//[[:space:]]/}" ]]; then
  echo "A non-empty --prompt or --prompt-file is required." >&2
  exit 2
fi

case "$DURATION" in
  6|10) ;;
  *) echo "--duration must be 6 or 10 seconds for the tested CLI path." >&2; exit 2 ;;
esac

case "$RESOLUTION" in
  480p|720p) ;;
  *) echo "--resolution must be 480p or 720p." >&2; exit 2 ;;
esac

if [[ -z "$OUTPUT_DIR" ]]; then
  echo "--output-dir is required." >&2
  exit 2
fi

for dependency in jq ffmpeg ffprobe; do
  command -v "$dependency" >/dev/null 2>&1 || { echo "$dependency is required." >&2; exit 127; }
done

GROK_BIN="${GROK_BIN:-$(command -v grok 2>/dev/null || true)}"
if [[ -z "$GROK_BIN" && -x "$HOME/.grok/bin/grok" ]]; then
  GROK_BIN="$HOME/.grok/bin/grok"
fi
if [[ -z "$GROK_BIN" || ! -x "$GROK_BIN" ]]; then
  echo "Grok CLI is not installed. Use call-grok to install and log in, then resume." >&2
  exit 127
fi

mkdir -p -- "$OUTPUT_DIR"
OUTPUT_DIR="$(cd -- "$OUTPUT_DIR" && pwd)"
IMAGE="$(cd -- "$(dirname -- "$IMAGE")" && pwd)/$(basename -- "$IMAGE")"
WORK_DIR="$(dirname -- "$IMAGE")"

read -r -d '' TASK_PROMPT <<EOF || true
Execute one approved video-generation tool call and nothing else. Use image_to_video exactly once with image="${IMAGE}", prompt="${PROMPT}", duration=${DURATION}, resolution_name="${RESOLUTION}". Do not plan shots, do not generate or edit an image, do not use reference_to_video, do not call any tool more than once, and do not retry if generation fails. After the tool returns, report the saved video path and stop.
EOF

SYSTEM_PROMPT='You are a bounded Grok Imagine execution worker. Call image_to_video exactly once with the user-supplied arguments. Do not plan, rewrite the prompt, call other tools, retry, or perform any other work. After the tool result, return only the saved path.'

set +e
RAW_OUTPUT="$("$GROK_BIN" \
  --cwd "$WORK_DIR" \
  --single "$TASK_PROMPT" \
  --output-format json \
  --tools image_to_video \
  --max-turns 2 \
  --no-subagents \
  --no-memory \
  --no-plan \
  --reasoning-effort low \
  --permission-mode dontAsk \
  --sandbox workspace \
  --system-prompt-override "$SYSTEM_PROMPT" 2>&1)"
RUN_STATUS=$?
set -e

if [[ $RUN_STATUS -ne 0 ]]; then
  if [[ "$RAW_OUTPUT" == *"Zero Data Retention"* || "$RAW_OUTPUT" == *"output.upload_url"* ]]; then
    echo "Grok blocked direct video output under Zero Data Retention. Stop without retrying; choose explicit Opt in or configure an owned R2/S3 upload URL." >&2
    exit 20
  fi
  printf '%s\n' "$RAW_OUTPUT" >&2
  exit "$RUN_STATUS"
fi

SESSION_ID="$(printf '%s' "$RAW_OUTPUT" | jq -r 'try .sessionId // empty' 2>/dev/null || true)"
if [[ -z "$SESSION_ID" ]]; then
  echo "Grok completed but no sessionId could be extracted; refusing to guess the output path." >&2
  printf '%s\n' "$RAW_OUTPUT" >&2
  exit 21
fi

VIDEO_PATH="$(find "$HOME/.grok/sessions" -type f -path "*/${SESSION_ID}/videos/*.mp4" -print 2>/dev/null | tail -1)"
if [[ -z "$VIDEO_PATH" || ! -s "$VIDEO_PATH" ]]; then
  echo "No non-empty MP4 was found for Grok session $SESSION_ID." >&2
  exit 22
fi

DELIVERED_PATH="$OUTPUT_DIR/grok-${SESSION_ID}-${DURATION}s-${RESOLUTION}.mp4"
cp -- "$VIDEO_PATH" "$DELIVERED_PATH"

PROBE_JSON="$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,width,height,r_frame_rate,duration -show_entries format=duration,size -of json "$DELIVERED_PATH")"
ACTUAL_DURATION="$(printf '%s' "$PROBE_JSON" | jq -r '.format.duration // .streams[0].duration // empty')"
if [[ -z "$ACTUAL_DURATION" ]]; then
  echo "ffprobe could not determine video duration." >&2
  exit 23
fi

if ! awk -v actual="$ACTUAL_DURATION" -v expected="$DURATION" 'BEGIN { delta=actual-expected; if (delta<0) delta=-delta; exit(delta <= 1.0 ? 0 : 1) }'; then
  echo "Generated video duration $ACTUAL_DURATION differs materially from requested ${DURATION}s." >&2
  exit 24
fi

if command -v shasum >/dev/null 2>&1; then
  SHA256="$(shasum -a 256 "$DELIVERED_PATH" | awk '{print $1}')"
else
  SHA256="$(sha256sum "$DELIVERED_PATH" | awk '{print $1}')"
fi

FRAMES_DIR="$OUTPUT_DIR/grok-${SESSION_ID}-frames"
mkdir -p -- "$FRAMES_DIR"
MIDPOINT="$(awk -v value="$ACTUAL_DURATION" 'BEGIN { printf "%.3f", value / 2 }')"
ENDING="$(awk -v value="$ACTUAL_DURATION" 'BEGIN { point=value-0.5; if (point<0) point=0; printf "%.3f", point }')"
ffmpeg -hide_banner -loglevel error -ss 0.5 -i "$DELIVERED_PATH" -frames:v 1 -q:v 2 "$FRAMES_DIR/start.jpg"
ffmpeg -hide_banner -loglevel error -ss "$MIDPOINT" -i "$DELIVERED_PATH" -frames:v 1 -q:v 2 "$FRAMES_DIR/middle.jpg"
ffmpeg -hide_banner -loglevel error -ss "$ENDING" -i "$DELIVERED_PATH" -frames:v 1 -q:v 2 "$FRAMES_DIR/end.jpg"

jq -n \
  --arg status "generated_needs_visual_qa" \
  --arg session_id "$SESSION_ID" \
  --arg source_session_path "$VIDEO_PATH" \
  --arg delivered_path "$DELIVERED_PATH" \
  --arg frames_dir "$FRAMES_DIR" \
  --arg sha256 "$SHA256" \
  --arg requested_duration "$DURATION" \
  --arg requested_resolution "$RESOLUTION" \
  --argjson probe "$PROBE_JSON" \
  '{status:$status,session_id:$session_id,source_session_path:$source_session_path,delivered_path:$delivered_path,frames_dir:$frames_dir,sha256:$sha256,requested:{duration_seconds:($requested_duration|tonumber),resolution:$requested_resolution},ffprobe:$probe,tool_calls:1,retried:false}'
