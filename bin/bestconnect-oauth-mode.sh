#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-}"
CONFIG_PATH="${BESTCONNECT_NGINX_OAUTH_CONFIG:-/etc/nginx/conf.d/localhost-oauth.conf}"

usage() {
  cat <<'USAGE'
Usage: bin/bestconnect-oauth-mode.sh frontend|postman|status

Modes:
  frontend  DATEV redirects to local Angular at http://localhost:4200/#/callback
  postman   DATEV redirects directly to backend /auth/callback for JSON output
  status    Print the active nginx callback config
USAGE
}

write_config() {
  local body="$1"

  printf '%s\n' "$body" | sudo tee "$CONFIG_PATH" >/dev/null
  sudo nginx -t
  sudo systemctl reload nginx || sudo systemctl restart nginx
}

frontend_config='server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name localhost;

    location = / {
        return 302 "http://localhost:4200/#/callback$is_args$args";
    }
}'

postman_config='server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name localhost;

    location = / {
        proxy_pass http://localhost:3003/auth/callback;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}'

case "$MODE" in
  frontend)
    write_config "$frontend_config"
    printf 'Bestconnect OAuth mode: frontend\n'
    ;;
  postman)
    write_config "$postman_config"
    printf 'Bestconnect OAuth mode: postman\n'
    ;;
  status)
    sudo cat "$CONFIG_PATH"
    ;;
  -h | --help | help | "")
    usage
    ;;
  *)
    printf 'Unknown mode: %s\n\n' "$MODE" >&2
    usage >&2
    exit 1
    ;;
esac
