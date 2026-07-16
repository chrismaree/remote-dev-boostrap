#!/usr/bin/env bash

# shellcheck disable=SC1090
source "${REMOTE_DEV_CONFIG_DIR}/config.env"

export PATH="${HOME}/.local/bin:${PATH}"

if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi

uv python install "${REMOTE_DEV_PYTHON_DEFAULT:-3.12}" --default

if [[ -n "${REMOTE_DEV_PYTHON_EXTRA:-}" ]]; then
  # shellcheck disable=SC2086
  uv python install ${REMOTE_DEV_PYTHON_EXTRA}
fi

uv tool install ruff >/dev/null 2>&1 || uv tool upgrade ruff >/dev/null 2>&1 || true
uv tool install pre-commit >/dev/null 2>&1 || uv tool upgrade pre-commit >/dev/null 2>&1 || true
