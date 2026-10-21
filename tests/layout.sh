#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
source lib/webdev-launcher.sh

# A workstation with no new settings keeps the original layout.
(
  unset PL_LAYOUT
  source lib/webdev-launcher.sh
  [[ "$PL_LAYOUT" == desktop ]]
)
git check-ignore -q .env.local
git check-ignore -q .profile

# Profile selection is independent of the project command and URL configuration.
(
  unset PL_PROFILE
  source lib/project-env.sh
  fixture="$(mktemp -d /tmp/project-launch-profile-test.XXXXXX)"
  mkdir "$fixture/profiles"
  cp profiles/*.env "$fixture/profiles/"
  printf '%s\n' 'OC_APP_URLS="http://localhost:4200|http://localhost:4201"' > "$fixture/.env"
  pl_load_project_env "$fixture"
  [[ "$PL_PROFILE" == desktop && "$PL_LAYOUT" == desktop ]]
  printf 'framework\n' > "$fixture/.profile"
  unset PL_PROFILE
  pl_load_project_env "$fixture"
  [[ "$PL_PROFILE" == framework && "$PL_LAYOUT" == laptop ]]
  [[ "$OC_APP_URLS" == 'http://localhost:4200|http://localhost:4201' ]]
  pl_load_project_env "$fixture" --profile desktop
  [[ "$PL_PROFILE" == desktop && "$PL_LAYOUT" == desktop ]]
  pl_load_project_env "$fixture" --profile framework
  [[ "$PL_PROFILE" == framework && "$PL_LAYOUT" == laptop ]]
  if pl_load_project_env "$fixture" --profile ../framework 2>/dev/null; then exit 1; fi
  if pl_load_project_env "$fixture" --profile 2>/dev/null; then exit 1; fi
)

check_layout() (
  local expected="$1" monitor_json="$2"
  PL_LAYOUT=auto
  hyprctl() { printf '%s\n' "$monitor_json"; }
  pl_resolve_layout >/dev/null
  [[ "$PL_LAYOUT" == "$expected" ]]
)

check_layout laptop '[{"width":2880,"height":1920,"scale":2,"focused":true}]'
check_layout desktop '[{"width":5120,"height":1440,"scale":1,"focused":true}]'
check_layout desktop '[{"width":3440,"height":1440,"scale":1.5,"focused":true}]'
check_layout laptop '[{"width":1920,"height":1080,"scale":1,"focused":true}]'
check_layout laptop '[{"width":2560,"height":1440,"scale":1,"transform":1,"focused":true}]'
check_layout desktop '[{"width":2880,"scale":2},{"width":3440,"scale":1,"focused":true}]'
check_layout laptop '[{"width":2880,"scale":2}]'

for forced in desktop laptop; do
  (
    PL_LAYOUT="$forced"
    hyprctl() { return 99; }
    pl_resolve_layout >/dev/null
    [[ "$PL_LAYOUT" == "$forced" ]]
  )
done
if (PL_LAYOUT=unknown; pl_resolve_layout) 2>/dev/null; then
  printf 'Invalid layout was accepted\n' >&2; exit 1
fi
if (PL_LAYOUT=auto; PL_LAPTOP_MAX_WIDTH=invalid; pl_resolve_layout) 2>/dev/null; then
  printf 'Invalid width was accepted\n' >&2; exit 1
fi
if (PL_LAYOUT=auto; hyprctl() { echo '[]'; }; pl_resolve_layout) 2>/dev/null; then
  printf 'Missing monitors were accepted\n' >&2; exit 1
fi

# Compare complete launch invocations, including terminal commands and every URL.
launch_inventory() (
  PL_LAYOUT="$1"
  APP_URLS=('http://localhost:4200' 'http://localhost:4201')
  JIRA_URLS=('https://example.atlassian.net/project')
  RIGHT_BROWSER_URLS=('https://mail.google.com' 'https://drive.google.com' 'https://github.com/owner/repo')
  sleep() { :; }
  pl_hypr_focus_workspace() { printf 'workspace %s\n' "$1"; }
  pl_hypr_exec() { printf '%q ' "$@"; printf '\n'; }
  pl_launch_workspace_1
  pl_launch_workspace_2
  pl_launch_workspace_3
  pl_launch_workspace_4
  pl_launch_workspace_5
)
[[ "$(launch_inventory desktop)" == "$(launch_inventory laptop)" ]]

layout_inventory() (
  PL_LAYOUT="$1"
  APP_URLS=('http://localhost:4200')
  JIRA_URLS=()
  RIGHT_BROWSER_URLS=('https://github.com')
  pl_group_workspace() { printf 'group %s %s\n' "$1" "$2"; }
  pl_apply_managed_resizes() { echo resize; }
  pl_apply_window_layout
)
[[ "$(layout_inventory desktop)" == resize ]]
[[ "$(layout_inventory laptop)" == $'group 1 3\ngroup 2 3\ngroup 3 1\ngroup 4 2\ngroup 5 2' ]]

# Count only mapped, unpinned windows on the requested workspace.
(
  PL_LAYOUT_WAIT_ATTEMPTS=1
  sleep() { :; }
  hyprctl() {
    if [[ "$1" == clients ]]; then
      printf '%s\n' '[{"workspace":{"id":1}},{"workspace":{"id":6}},{"workspace":{"id":1},"mapped":false},{"workspace":{"id":1},"pinned":true}]'
    else
      printf '%s\n' "$*"
    fi
  }
  result="$(pl_group_workspace 1 1 test-codex)"
  [[ "$result" == *'laptop-layout.lua'*'(1, "test-codex")' ]]
  if pl_group_workspace 6 1; then exit 1; fi
)

lua tests/laptop-layout.lua
printf 'Layout checks passed: detection, overrides, identical launch lists, workspace limits, grouping.\n'
