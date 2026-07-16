#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib/common.sh
source "${ROOT_DIR}/lib/common.sh"

PROFILE="full"
INSTALL_DOCKER=1
INSTALL_GCLOUD=1
INSTALL_FOUNDRY=1
INSTALL_CODEX=1
INSTALL_TAILSCALE=1
TAILSCALE_UP=0

usage() {
  cat <<'EOF'
Usage: install.sh [options]

Options:
  --profile minimal|core|full
  --without-docker
  --without-gcloud
  --without-foundry
  --without-codex
  --without-tailscale
  --tailscale-up
  -h, --help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      [[ $# -ge 2 ]] || die "--profile requires a value"
      PROFILE="$2"
      shift 2
      ;;
    --without-docker) INSTALL_DOCKER=0; shift ;;
    --without-gcloud) INSTALL_GCLOUD=0; shift ;;
    --without-foundry) INSTALL_FOUNDRY=0; shift ;;
    --without-codex) INSTALL_CODEX=0; shift ;;
    --without-tailscale) INSTALL_TAILSCALE=0; shift ;;
    --tailscale-up) TAILSCALE_UP=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

case "${PROFILE}" in
  minimal|core|full) ;;
  *) die "Unknown profile '${PROFILE}'. Expected minimal, core, or full." ;;
esac

require_supported_host
ensure_user_directories
install_default_config

log "Installing profile: ${PROFILE}"
run_module system
run_module shell
install_managed_dotfiles
install_remote_dev_command

if profile_at_least core; then
  run_module python
  run_module node
fi

if [[ "${PROFILE}" == "full" ]]; then
  run_module github
  [[ "${INSTALL_DOCKER}" -eq 1 ]] && run_module docker
  [[ "${INSTALL_GCLOUD}" -eq 1 ]] && run_module gcloud
  [[ "${INSTALL_FOUNDRY}" -eq 1 ]] && run_module foundry
  [[ "${INSTALL_CODEX}" -eq 1 ]] && run_module codex
  [[ "${INSTALL_TAILSCALE}" -eq 1 ]] && run_module tailscale
fi

write_install_state "${PROFILE}"

if [[ "${TAILSCALE_UP}" -eq 1 && "${INSTALL_TAILSCALE}" -eq 1 ]]; then
  "${HOME}/.local/bin/remote-dev" tailscale
fi

print_completion_summary
