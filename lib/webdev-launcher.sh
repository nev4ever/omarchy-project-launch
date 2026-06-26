#!/usr/bin/env bash

# Shared Omarchy/Hyprland project launcher for web-development workspaces.

PROJECT_NAME="${PROJECT_NAME:-Project}"
PROJECT_ID="${PROJECT_ID:-project}"
SESSION="${SESSION:-$PROJECT_ID}"
CODEX_SESSION="${CODEX_SESSION:-${SESSION}-codex}"
NVIM_SESSION="${NVIM_SESSION:-${SESSION}-nvim}"

PL_TERM="${PL_TERM:-kitty}"
PL_BROWSER="${PL_BROWSER:-chromium}"
PL_FILE_MANAGER="${PL_FILE_MANAGER:-nautilus}"
PL_CLOSE_MAX_WORKSPACE="${PL_CLOSE_MAX_WORKSPACE:-5}"
PL_LAUNCH_DELAY="${PL_LAUNCH_DELAY:-0.8}"
PL_DETACH_LOG="${PL_DETACH_LOG:-/tmp/project-launch-${PROJECT_ID}.log}"
PL_RESET_TMUX="${PL_RESET_TMUX:-0}"

CODEX_DIR="${CODEX_DIR:-$HOME}"
NVIM_DIR="${NVIM_DIR:-$CODEX_DIR}"
RUN_DIR="${RUN_DIR:-$CODEX_DIR}"
CODEX_COMMAND="${CODEX_COMMAND:-codex}"
NVIM_COMMAND="${NVIM_COMMAND:-nvim .}"

POSTMAN_ENABLED="${POSTMAN_ENABLED:-1}"
POSTMAN_COMMAND="${POSTMAN_COMMAND:-postman}"
WHATSAPP_COMMAND="${WHATSAPP_COMMAND:-omarchy-launch-webapp \"https://web.whatsapp.com/\"}"
HEY_COMMAND="${HEY_COMMAND:-omarchy-launch-webapp \"https://app.hey.com\"}"

pl_init_array() {
  local name="$1"

  if ! declare -p "$name" >/dev/null 2>&1; then
    eval "declare -ga ${name}=()"
  else
    eval "declare -ga ${name}"
  fi
}

pl_init_array DOCKER_COMMANDS
pl_init_array PREFLIGHT_COMMANDS
pl_init_array TMUX_WINDOWS
pl_init_array APP_URLS
pl_init_array JIRA_URLS
pl_init_array RIGHT_BROWSER_URLS
pl_init_array FILE_BROWSER_DIRS
pl_init_array MANAGED_RESIZES

if [[ "${#FILE_BROWSER_DIRS[@]}" -eq 0 ]]; then
  FILE_BROWSER_DIRS=("$HOME" "$HOME")
fi

pl_array_from_env() {
  local -n target_array="$1"
  local value="${2:-}"
  local -a parts=()

  target_array=()
  [[ -n "$value" ]] || return 0

  IFS='|' read -r -a parts <<<"$value"
  target_array=("${parts[@]}")
}

pl_require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$command_name" >&2
    exit 1
  fi
}

pl_require_base_commands() {
  pl_require_command hyprctl
  pl_require_command jq
  pl_require_command tmux
  pl_require_command "$PL_TERM"
  pl_require_command "$PL_BROWSER"
  pl_require_command "$PL_FILE_MANAGER"
}

pl_detach_if_needed() {
  [[ "${PROJECT_LAUNCH_DETACHED:-0}" == 1 ]] && return 0
  [[ -t 0 || -t 1 || -t 2 ]] || return 0

  local script_path="${PROJECT_LAUNCH_SCRIPT:-${BASH_SOURCE[-1]}}"
  if [[ ! -f "$script_path" ]]; then
    script_path="$0"
  fi

  script_path="$(cd -- "$(dirname -- "$script_path")" && pwd)/$(basename -- "$script_path")"

  printf 'Launching %s workspace in background. Log: %s\n' "$PROJECT_NAME" "$PL_DETACH_LOG"
  PROJECT_LAUNCH_DETACHED=1 setsid bash "$script_path" "$@" >"$PL_DETACH_LOG" 2>&1 < /dev/null &
  exit 0
}

pl_shell_cd_command() {
  local dir="$1"
  local command="$2"
  local quoted_dir

  printf -v quoted_dir '%q' "$dir"
  printf 'cd %s; %s' "$quoted_dir" "$command"
}

pl_quote_command() {
  printf '%q ' "$@"
}

pl_hypr_exec() {
  local workspace="$1"
  shift

  local command
  command="$(pl_quote_command "$@")"
  hyprctl dispatch exec "[workspace ${workspace} silent] ${command}" >/dev/null
}

pl_hypr_exec_shell() {
  local workspace="$1"
  local command="$2"

  pl_hypr_exec "$workspace" bash -lc "$command"
}

pl_launch_terminal() {
  local workspace="$1"
  local title="$2"
  local dir="$3"
  local command="$4"

  pl_hypr_exec "$workspace" "$PL_TERM" --title "$title" -e bash -lc "$(pl_shell_cd_command "$dir" "exec $command")"
}

pl_close_workspaces() {
  local addresses

  mapfile -t addresses < <(
    hyprctl clients -j |
      jq -r --argjson max_workspace "$PL_CLOSE_MAX_WORKSPACE" \
        '.[] | select(.workspace.id >= 1 and .workspace.id <= $max_workspace) | .address'
  )

  for address in "${addresses[@]}"; do
    hyprctl dispatch closewindow "address:$address" >/dev/null 2>&1 || true
    sleep 0.05
  done
}

pl_run_project_command() {
  local dir="$1"
  local command="$2"

  (
    cd "$dir"
    bash -lc "$command"
  )
}

pl_run_docker_commands() {
  local spec dir command

  for spec in "${DOCKER_COMMANDS[@]}"; do
    IFS='|' read -r dir command <<<"$spec"
    [[ -n "${dir:-}" && -n "${command:-}" ]] || continue
    pl_run_project_command "$dir" "$command"
  done
}

pl_run_preflight_commands() {
  local spec dir command

  [[ "${PROJECT_LAUNCH_DETACHED:-0}" == 1 ]] && return 0

  for spec in "${PREFLIGHT_COMMANDS[@]}"; do
    IFS='|' read -r dir command <<<"$spec"
    [[ -n "${dir:-}" && -n "${command:-}" ]] || continue
    pl_run_project_command "$dir" "$command"
  done
}

pl_kill_tmux_sessions() {
  local session killed
  killed=""

  for session in "$CODEX_SESSION" "$NVIM_SESSION" "$SESSION"; do
    [[ -n "$session" ]] || continue
    [[ " $killed " == *" $session "* ]] && continue
    tmux has-session -t "$session" 2>/dev/null && tmux kill-session -t "$session"
    killed="$killed $session"
  done
}

pl_reset_tmux_sessions() {
  [[ "$PL_RESET_TMUX" == 1 ]] || return 0
  pl_kill_tmux_sessions
}

pl_tmux_session_exists() {
  local session="$1"
  tmux has-session -t "$session" 2>/dev/null
}

pl_create_single_tmux_session() {
  local session="$1"
  local window_name="$2"
  local dir="$3"
  local command="$4"
  local pane_id

  if pl_tmux_session_exists "$session"; then
    printf 'Reusing existing tmux session: %s\n' "$session"
    return 0
  fi

  pane_id="$(tmux new-session -d -P -F '#{pane_id}' -s "$session" -n "$window_name" -c "$dir")"
  tmux send-keys -t "$pane_id" "$(pl_shell_cd_command "$dir" "$command")" C-m
}

pl_create_tool_tmux_sessions() {
  pl_create_single_tmux_session "$CODEX_SESSION" codex "$CODEX_DIR" "$CODEX_COMMAND"
  pl_create_single_tmux_session "$NVIM_SESSION" nvim "$NVIM_DIR" "$NVIM_COMMAND"
}

pl_create_run_tmux_session() {
  local spec name dir command split_dir split_command first_window first_name top_pane split_pane

  if pl_tmux_session_exists "$SESSION"; then
    printf 'Reusing existing tmux session: %s\n' "$SESSION"
    return 0
  fi

  first_window=1
  first_name=""

  for spec in "${TMUX_WINDOWS[@]}"; do
    IFS='|' read -r name dir command split_dir split_command <<<"$spec"
    [[ -n "${name:-}" && -n "${dir:-}" ]] || continue

    if [[ "$first_window" == 1 ]]; then
      top_pane="$(tmux new-session -d -P -F '#{pane_id}' -s "$SESSION" -n "$name" -c "$dir")"
      first_window=0
      first_name="$name"
    else
      top_pane="$(tmux new-window -P -F '#{pane_id}' -t "$SESSION" -n "$name" -c "$dir")"
    fi

    if [[ -n "${command:-}" ]]; then
      tmux send-keys -t "$top_pane" "$(pl_shell_cd_command "$dir" "$command")" C-m
    fi

    if [[ -n "${split_command:-}" ]]; then
      split_dir="${split_dir:-$dir}"
      split_pane="$(tmux split-window -P -F '#{pane_id}' -v -t "$top_pane" -c "$split_dir")"
      tmux send-keys -t "$split_pane" "$(pl_shell_cd_command "$split_dir" "$split_command")" C-m
      tmux select-layout -t "$top_pane" even-vertical
      tmux select-pane -t "$top_pane"
    fi
  done

  if [[ "$first_window" == 1 ]]; then
    tmux new-session -d -s "$SESSION" -n shell -c "$RUN_DIR"
    first_name="shell"
  fi

  tmux select-window -t "$SESSION:$first_name"
}

pl_launch_browser_window() {
  local workspace="$1"
  shift

  [[ "$#" -gt 0 ]] || return 0
  pl_hypr_exec "$workspace" "$PL_BROWSER" --new-window "$@"
}

pl_launch_workspace_1() {
  hyprctl dispatch workspace 1 >/dev/null
  pl_launch_terminal 1 "${PROJECT_ID}-codex" "$CODEX_DIR" "tmux attach -t '$CODEX_SESSION'"
  sleep "$PL_LAUNCH_DELAY"
  pl_launch_terminal 1 "${PROJECT_ID}-nvim" "$NVIM_DIR" "tmux attach -t '$NVIM_SESSION'"
  sleep "$PL_LAUNCH_DELAY"
  pl_launch_terminal 1 "${PROJECT_ID}-run" "$RUN_DIR" "tmux attach -t '$SESSION'"
  sleep "$PL_LAUNCH_DELAY"
}

pl_launch_workspace_2() {
  hyprctl dispatch workspace 2 >/dev/null
  pl_launch_browser_window 2 "${APP_URLS[@]}"
  sleep "$PL_LAUNCH_DELAY"
  pl_launch_terminal 2 "${PROJECT_ID}-run-mirror" "$RUN_DIR" "tmux attach -t '$SESSION'"
  sleep "$PL_LAUNCH_DELAY"

  if [[ "$POSTMAN_ENABLED" == 1 ]]; then
    pl_hypr_exec_shell 2 "$POSTMAN_COMMAND"
    sleep "$PL_LAUNCH_DELAY"
  fi
}

pl_launch_workspace_3() {
  hyprctl dispatch workspace 3 >/dev/null
  pl_launch_browser_window 3 "${JIRA_URLS[@]}"
  sleep "$PL_LAUNCH_DELAY"
  pl_launch_browser_window 3 "${RIGHT_BROWSER_URLS[@]}"
  sleep "$PL_LAUNCH_DELAY"
}

pl_launch_workspace_4() {
  hyprctl dispatch workspace 4 >/dev/null
  pl_hypr_exec_shell 4 "$WHATSAPP_COMMAND"
  sleep "$PL_LAUNCH_DELAY"
  pl_hypr_exec_shell 4 "$HEY_COMMAND"
  sleep "$PL_LAUNCH_DELAY"
}

pl_launch_workspace_5() {
  hyprctl dispatch workspace 5 >/dev/null

  if [[ "${#FILE_BROWSER_DIRS[@]}" -gt 0 ]]; then
    pl_hypr_exec 5 "$PL_FILE_MANAGER" "${FILE_BROWSER_DIRS[0]}"
    sleep "$PL_LAUNCH_DELAY"
  fi

  if [[ "${#FILE_BROWSER_DIRS[@]}" -gt 1 ]]; then
    pl_hypr_exec 5 "$PL_FILE_MANAGER" "${FILE_BROWSER_DIRS[1]}"
    sleep "$PL_LAUNCH_DELAY"
  fi
}

pl_selector_exists() {
  local selector="$1"
  local kind value

  case "$selector" in
    address:*)
      kind="address"
      value="${selector#address:}"
      ;;
    title:*)
      kind="title"
      value="${selector#title:}"
      ;;
    initialtitle:*)
      kind="initialTitle"
      value="${selector#initialtitle:}"
      ;;
    class:*)
      kind="class"
      value="${selector#class:}"
      ;;
    initialclass:*)
      kind="initialClass"
      value="${selector#initialclass:}"
      ;;
    *)
      kind="class"
      value="$selector"
      ;;
  esac

  hyprctl clients -j |
    jq -e --arg kind "$kind" --arg value "$value" '
      any(.[]; ((.[$kind] // "") | test($value)))
    ' >/dev/null
}

pl_wait_for_selector() {
  local selector="$1"
  local attempts="${2:-30}"
  local i

  for ((i = 0; i < attempts; i++)); do
    if pl_selector_exists "$selector" 2>/dev/null; then
      return 0
    fi
    sleep 0.25
  done

  return 1
}

pl_apply_managed_resizes() {
  local spec workspace selector resize_params

  for spec in "${MANAGED_RESIZES[@]}"; do
    IFS='|' read -r workspace selector resize_params <<<"$spec"
    [[ -n "${workspace:-}" && -n "${selector:-}" && -n "${resize_params:-}" ]] || continue

    hyprctl dispatch workspace "$workspace" >/dev/null 2>&1 || true
    if ! pl_wait_for_selector "$selector"; then
      printf 'Resize skipped: no window matched %s on workspace %s\n' "$selector" "$workspace" >&2
      continue
    fi

    if hyprctl dispatch resizewindowpixel "${resize_params},${selector}" >/dev/null 2>&1; then
      printf 'Resize applied: workspace=%s selector=%s params=%s\n' "$workspace" "$selector" "$resize_params"
    else
      printf 'Resize failed: workspace=%s selector=%s params=%s\n' "$workspace" "$selector" "$resize_params" >&2
    fi
  done
}

launch_webdev_project() {
  pl_run_preflight_commands
  pl_detach_if_needed "$@"
  printf 'Launching %s workspace...\n' "$PROJECT_NAME"

  pl_require_base_commands
  pl_close_workspaces
  pl_reset_tmux_sessions
  pl_run_docker_commands
  pl_create_tool_tmux_sessions
  pl_create_run_tmux_session

  pl_launch_workspace_1
  pl_launch_workspace_2
  pl_launch_workspace_3
  pl_launch_workspace_4
  pl_launch_workspace_5
  pl_apply_managed_resizes

  hyprctl dispatch workspace 1 >/dev/null
}
