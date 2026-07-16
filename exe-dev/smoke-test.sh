#!/usr/bin/env bash
set -Eeuo pipefail

required_commands=(
  remote-dev
  zsh
  tmux
  python
  uv
  node
  yarn
  docker
  gh
  gcloud
  forge
  codex
)

failed=0

for command_name in "${required_commands[@]}"; do
  if command -v "${command_name}" >/dev/null 2>&1; then
    printf 'ok      %s\n' "${command_name}"
  else
    printf 'missing %s\n' "${command_name}" >&2
    failed=1
  fi
done

printf '\n'
remote-dev doctor

if [[ "${failed}" -ne 0 ]]; then
  printf '\nOne or more required commands are missing.\n' >&2
  exit 1
fi

printf '\nBootstrap smoke test passed.\n'
