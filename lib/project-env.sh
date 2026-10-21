#!/usr/bin/env bash

# Shared project values, then a tracked machine profile, then local overrides.
pl_load_project_env() {
  local dir="$1"
  shift
  local profile="${PL_PROFILE:-}" env_file

  if [[ -f "$dir/.env" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "$dir/.env"
    set +a
  fi

  profile="${PL_PROFILE:-$profile}"
  if [[ "${1:-}" == --profile ]]; then
    if [[ -z "${2:-}" ]]; then
      printf 'Usage: %s [--profile desktop|framework]\n' "$0" >&2
      return 1
    fi
    profile="$2"
  elif [[ -z "$profile" && -f "$dir/.profile" ]]; then
    profile="$(<"$dir/.profile")"
  fi
  profile="${profile:-desktop}"

  if [[ ! "$profile" =~ ^[[:alnum:]_-]+$ || ! -f "$dir/profiles/$profile.env" ]]; then
    printf 'Unknown launcher profile: %s\n' "$profile" >&2
    return 1
  fi
  env_file="$dir/profiles/$profile.env"
  set -a
  # shellcheck source=/dev/null
  source "$env_file"
  set +a
  PL_PROFILE="$profile"

  if [[ -f "$dir/.env.local" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "$dir/.env.local"
    set +a
  fi
}
