#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="$HOME/.config/skwd-wall/.env"

if [[ -f "$ENV_FILE" ]]; then
  # Export all variables from .env into this process environment
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

exec qs
