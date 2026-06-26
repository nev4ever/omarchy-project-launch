#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAUNCH_SCRIPT="$SCRIPT_DIR/bestconnect.sh"

if [[ -f "$SCRIPT_DIR/.env" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$SCRIPT_DIR/.env"
  set +a
fi

PROJECT_NAME="${BESTCONNECT_PROJECT_NAME:-Bestconnect}"
PROJECT_ID="${BESTCONNECT_PROJECT_ID:-bc}"
SESSION="${BESTCONNECT_SESSION:-bestconnect}"

PROJECT_ROOT="${BESTCONNECT_ROOT_DIR:-$HOME/dev/bestconnect}"

CODEX_DIR="${BESTCONNECT_CODEX_DIR:-$PROJECT_ROOT}"
NVIM_DIR="${BESTCONNECT_NVIM_DIR:-$PROJECT_ROOT}"
RUN_DIR="${BESTCONNECT_RUN_DIR:-$PROJECT_ROOT}"
CODEX_COMMAND="${BESTCONNECT_CODEX_COMMAND:-codex}"

source "$SCRIPT_DIR/lib/webdev-launcher.sh"

pl_array_from_env APP_URLS "${BESTCONNECT_APP_URLS:-http://localhost:3000}"
pl_array_from_env JIRA_URLS "${BESTCONNECT_JIRA_URLS:-}"
pl_array_from_env RIGHT_BROWSER_URLS "${BESTCONNECT_RIGHT_BROWSER_URLS:-https://mail.google.com|https://drive.google.com|https://calendar.google.com|https://github.com}"
pl_array_from_env MANAGED_RESIZES "${BESTCONNECT_MANAGED_RESIZES:-}"

if [[ -n "${BESTCONNECT_DOCKER_START_COMMAND:-}" ]]; then
  DOCKER_COMMANDS=("$PROJECT_ROOT|$BESTCONNECT_DOCKER_START_COMMAND")
fi

TMUX_WINDOWS=(
  "app|$PROJECT_ROOT|${BESTCONNECT_APP_COMMAND:-deno task dev}|$PROJECT_ROOT|${BESTCONNECT_LOG_COMMAND:-}"
  "tests|$PROJECT_ROOT|${BESTCONNECT_TEST_COMMAND:-deno test --allow-read --allow-write --allow-env --unstable}||"
)

launch_webdev_project "$@"
