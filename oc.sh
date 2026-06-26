#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_LAUNCH_SCRIPT="$SCRIPT_DIR/oc.sh"

if [[ -f "$SCRIPT_DIR/.env" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$SCRIPT_DIR/.env"
  set +a
fi

PROJECT_NAME="${OC_PROJECT_NAME:-OC}"
PROJECT_ID="${OC_PROJECT_ID:-oc}"
SESSION="${OC_SESSION:-oc}"

OC_ROOT_DIR="${OC_ROOT_DIR:-$HOME/dev/oc}"
OC_FRONTEND_DIR="${OC_FRONTEND_DIR:-$HOME/dev/oc-frontend}"
OC_CONFIG_FRONTEND_DIR="${OC_CONFIG_FRONTEND_DIR:-$HOME/dev/oc-config-frontend}"

CODEX_DIR="${OC_CODEX_DIR:-$OC_ROOT_DIR}"
NVIM_DIR="${OC_NVIM_DIR:-$OC_ROOT_DIR}"
RUN_DIR="${OC_RUN_DIR:-$OC_ROOT_DIR}"
CODEX_COMMAND="${OC_CODEX_COMMAND:-codex}"

source "$SCRIPT_DIR/lib/webdev-launcher.sh"

pl_array_from_env APP_URLS "${OC_APP_URLS:-http://localhost:4200|http://localhost:4201}"
pl_array_from_env JIRA_URLS "${OC_JIRA_URLS:-}"
pl_array_from_env RIGHT_BROWSER_URLS "${OC_RIGHT_BROWSER_URLS:-https://mail.google.com|https://drive.google.com|https://calendar.google.com|https://github.com}"
pl_array_from_env MANAGED_RESIZES "${OC_MANAGED_RESIZES:-}"

if [[ -n "${OC_DOCKER_START_COMMAND:-}" ]]; then
  DOCKER_COMMANDS=("$OC_ROOT_DIR|$OC_DOCKER_START_COMMAND")
fi

TMUX_WINDOWS=(
  "server|$OC_ROOT_DIR|${OC_SERVER_COMMAND:-npm run dev:server}|$OC_ROOT_DIR|${OC_BACKEND_COMMAND:-npm run dev:backend}"
  "frontend|$OC_FRONTEND_DIR|${OC_FRONTEND_COMMAND:-npm run start:local}|$OC_CONFIG_FRONTEND_DIR|${OC_CONFIG_FRONTEND_COMMAND:-npm run start:local:fixed}"
)

launch_webdev_project "$@"
