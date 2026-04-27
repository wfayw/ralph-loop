#!/usr/bin/env bash
set -euo pipefail

TOOL="codex"
MAX_ITERATIONS=10
VALIDATE_ONLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tool)
      TOOL="$2"
      shift 2
      ;;
    --tool=*)
      TOOL="${1#*=}"
      shift
      ;;
    --validate)
      VALIDATE_ONLY=1
      shift
      ;;
    --repo-root)
      export RALPH_REPO_ROOT="$2"
      shift 2
      ;;
    --repo-root=*)
      export RALPH_REPO_ROOT="${1#*=}"
      shift
      ;;
    *)
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        MAX_ITERATIONS="$1"
      fi
      shift
      ;;
  esac
done

if [[ "$TOOL" != "codex" && "$TOOL" != "amp" && "$TOOL" != "claude" ]]; then
  echo "Error: invalid --tool value '$TOOL'. Supported: codex, amp, claude."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT_DEFAULT="$SCRIPT_DIR"
REPO_ROOT="${RALPH_REPO_ROOT:-$REPO_ROOT_DEFAULT}"
if [[ -n "${RALPH_PRD_FILE:-}" ]]; then
  PRD_FILE="${RALPH_PRD_FILE}"
else
  PRD_FILE="$SCRIPT_DIR/prd.json"
fi
PRD_EXAMPLE_FILE="$SCRIPT_DIR/prd.json.example"
PROGRESS_FILE="${RALPH_PROGRESS_FILE:-$SCRIPT_DIR/progress.txt}"
PROMPT_FILE_CODEX="${RALPH_PROMPT_FILE_CODEX:-$SCRIPT_DIR/CODEX.md}"
PROMPT_FILE_AMP="${RALPH_PROMPT_FILE_AMP:-$SCRIPT_DIR/prompt.md}"
PROMPT_FILE_CLAUDE="${RALPH_PROMPT_FILE_CLAUDE:-$SCRIPT_DIR/CLAUDE.md}"
ARCHIVE_DIR="${RALPH_ARCHIVE_DIR:-$SCRIPT_DIR/archive}"
RUNS_DIR="${RALPH_RUNS_DIR:-$SCRIPT_DIR/runs}"
LAST_BRANCH_FILE="$SCRIPT_DIR/.last-branch"
LAST_MESSAGE_FILE="$SCRIPT_DIR/.last-message.txt"
RENDERED_CODEX_PROMPT_FILE="$SCRIPT_DIR/.rendered-CODEX.md"
FAIL_ON_MAX_ITERATIONS="${RALPH_FAIL_ON_MAX_ITERATIONS:-0}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: required command not found: $1"
    exit 1
  fi
}

json_read() {
  local file_path="$1"
  local python_expr="$2"
  python3 - "$file_path" "$python_expr" <<'PY'
import json
import sys
from pathlib import Path

file_path = Path(sys.argv[1])
expr = sys.argv[2]
data = json.loads(file_path.read_text(encoding="utf-8"))

if expr == "branchName":
    value = data.get("branchName", "")
elif expr == "userStoriesCount":
    value = len(data.get("userStories", []))
else:
    raise SystemExit(f"Unsupported expression: {expr}")

print(value)
PY
}

run_tool() {
  local mode="$1"
  case "$TOOL" in
    codex)
      shift
      local -a args
      args=(exec -C "$REPO_ROOT" --skip-git-repo-check)

      if [[ "$mode" == "validate" ]]; then
        args+=(--ephemeral --sandbox read-only)
      else
        if [[ -n "${RALPH_CODEX_SANDBOX:-}" ]]; then
          args+=(--sandbox "${RALPH_CODEX_SANDBOX}")
        else
          args+=(--dangerously-bypass-approvals-and-sandbox)
        fi
      fi

      if [[ -n "${RALPH_CODEX_MODEL:-}" ]]; then
        args+=(-m "${RALPH_CODEX_MODEL}")
      fi

      args+=(-o "$LAST_MESSAGE_FILE")
      codex "${args[@]}" "$@"
      ;;
    amp)
      if ! command -v amp >/dev/null 2>&1; then
        echo "Error: amp is not installed."
        return 1
      fi
      cat "$PROMPT_FILE_AMP" | amp --dangerously-allow-all
      ;;
    claude)
      if ! command -v claude >/dev/null 2>&1; then
        echo "Error: claude is not installed."
        return 1
      fi
      claude --dangerously-skip-permissions --print < "$PROMPT_FILE_CLAUDE"
      ;;
  esac
}

init_progress_file() {
  if [[ -f "$PROGRESS_FILE" ]]; then
    return
  fi

  cat > "$PROGRESS_FILE" <<EOF
## Codebase Patterns

## Session Log
Started: $(date)
---
EOF
}

archive_if_branch_changed() {
  if [[ ! -f "$PRD_FILE" || ! -f "$LAST_BRANCH_FILE" ]]; then
    return
  fi

  local current_branch last_branch date_stamp folder_name archive_folder
  current_branch="$(json_read "$PRD_FILE" branchName 2>/dev/null || echo "")"
  last_branch="$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")"

  if [[ -z "$current_branch" || -z "$last_branch" || "$current_branch" == "$last_branch" ]]; then
    return
  fi

  date_stamp="$(date +%Y-%m-%d)"
  folder_name="$(echo "$last_branch" | sed 's|^ralph/||')"
  archive_folder="$ARCHIVE_DIR/$date_stamp-$folder_name"

  mkdir -p "$archive_folder"
  [[ -f "$PRD_FILE" ]] && cp "$PRD_FILE" "$archive_folder/"
  [[ -f "$PROGRESS_FILE" ]] && cp "$PROGRESS_FILE" "$archive_folder/"
}

track_current_branch() {
  if [[ ! -f "$PRD_FILE" ]]; then
    return
  fi

  local current_branch
  current_branch="$(json_read "$PRD_FILE" branchName 2>/dev/null || echo "")"
  if [[ -n "$current_branch" ]]; then
    echo "$current_branch" > "$LAST_BRANCH_FILE"
  fi
}

prepare_run_log() {
  mkdir -p "$RUNS_DIR"
  local timestamp
  timestamp="$(date +%Y-%m-%dT%H-%M-%S)"
  echo "$RUNS_DIR/${timestamp}-${1}.log"
}

render_codex_prompt() {
  python3 - "$PROMPT_FILE_CODEX" "$RENDERED_CODEX_PROMPT_FILE" "$PRD_FILE" "$PROGRESS_FILE" <<'PY'
from pathlib import Path
import sys

template_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])
prd_file = sys.argv[3]
progress_file = sys.argv[4]

text = template_path.read_text(encoding="utf-8")
text = text.replace("{{PRD_FILE}}", prd_file)
text = text.replace("{{PROGRESS_FILE}}", progress_file)
output_path.write_text(text, encoding="utf-8")
PY
}

last_message_signals_complete() {
  local message_file="$1"
  if [[ ! -f "$message_file" ]]; then
    return 1
  fi

  local last_non_empty_line
  last_non_empty_line="$(
    awk '
      NF {
        line = $0
      }
      END {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
        print line
      }
    ' "$message_file"
  )"

  [[ "$last_non_empty_line" == "<promise>COMPLETE</promise>" ]]
}

run_validation() {
  require_cmd codex
  require_cmd git

  rm -f "$LAST_MESSAGE_FILE"
  local run_log
  run_log="$(prepare_run_log validate)"

  cat <<EOF | run_tool validate 2>&1 | tee "$run_log" >/dev/null
You are validating the Codex wiring for the Ralph installation in this repository.

1. Confirm the working root is a git repository with README.md.
2. Read AGENTS.md if it exists.
3. Read $PRD_EXAMPLE_FILE.
4. Output exactly three lines:
VALIDATION_OK
repo_root=<absolute path to repository root>
sample_story_count=<number of user stories in prd.json.example>

Do not modify any files.
EOF

  cat "$LAST_MESSAGE_FILE"
  echo ""
  echo "Validation log: $run_log"
  grep -q '^VALIDATION_OK$' "$LAST_MESSAGE_FILE"
}

run_iterations() {
  require_cmd codex
  require_cmd git

  if [[ ! -f "$PRD_FILE" ]]; then
    echo "Error: $PRD_FILE does not exist."
    echo "Create it from the example first:"
    echo "  cp $PRD_EXAMPLE_FILE $PRD_FILE"
    exit 1
  fi

  archive_if_branch_changed
  init_progress_file
  track_current_branch
  render_codex_prompt

  local run_log
  run_log="$(prepare_run_log run)"

  echo "Starting Ralph for Codex"
  echo "Repository root: $REPO_ROOT"
  echo "PRD file: $PRD_FILE"
  echo "Max iterations: $MAX_ITERATIONS"
  echo "Run log: $run_log"
  {
    echo "Starting Ralph for Codex"
    echo "Repository root: $REPO_ROOT"
    echo "PRD file: $PRD_FILE"
    echo "Max iterations: $MAX_ITERATIONS"
    echo "Run log: $run_log"
  } >>"$run_log"

  for i in $(seq 1 "$MAX_ITERATIONS"); do
    echo ""
    echo "==============================================================="
    echo "  Ralph Iteration $i of $MAX_ITERATIONS (codex)"
    echo "==============================================================="
    {
      echo ""
      echo "==============================================================="
      echo "  Ralph Iteration $i of $MAX_ITERATIONS ($TOOL)"
      echo "==============================================================="
    } >>"$run_log"

    rm -f "$LAST_MESSAGE_FILE"
    case "$TOOL" in
      codex)
        run_tool run < "$RENDERED_CODEX_PROMPT_FILE" 2>&1 | tee -a "$run_log" /dev/stderr || true
        ;;
      amp)
        run_tool run 2>&1 | tee -a "$run_log" /dev/stderr || true
        ;;
      claude)
        run_tool run 2>&1 | tee -a "$run_log" /dev/stderr || true
        ;;
    esac

    if last_message_signals_complete "$LAST_MESSAGE_FILE"; then
      echo ""
      echo "Ralph completed all stories."
      echo "Ralph completed all stories." >>"$run_log"
      return 0
    fi

    echo "Iteration $i complete. Continuing..."
    echo "Iteration $i complete. Continuing..." >>"$run_log"
    sleep 2
  done

  echo ""
  echo "Ralph reached max iterations ($MAX_ITERATIONS) without completing all stories."
  echo "Check $PROGRESS_FILE for details."
  echo "Ralph reached max iterations ($MAX_ITERATIONS) without completing all stories." >>"$run_log"
  echo "Check $PROGRESS_FILE for details." >>"$run_log"
  if [[ "$FAIL_ON_MAX_ITERATIONS" == "1" ]]; then
    return 1
  fi

  echo "Stopping normally because Ralph saved partial progress for the next run." >>"$run_log"
  return 0
}

if [[ "$VALIDATE_ONLY" == "1" ]]; then
  run_validation
else
  run_iterations
fi
