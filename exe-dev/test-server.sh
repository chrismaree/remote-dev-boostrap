#!/usr/bin/env bash
set -Eeuo pipefail

PORT="${PORT:-3000}"
HOSTNAME_SHORT="$(hostname -s)"
DIRECTORY="${1:-${HOME}/projects}"

mkdir -p "${DIRECTORY}"

printf 'Serving %s on http://0.0.0.0:%s\n' "${DIRECTORY}" "${PORT}"
printf 'Open privately at https://%s.exe.xyz:%s/\n' "${HOSTNAME_SHORT}" "${PORT}"
exec python -m http.server "${PORT}" --bind 0.0.0.0 --directory "${DIRECTORY}"
