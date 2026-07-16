#!/usr/bin/env bash

REMOTE_DEV_CONFIG_DIR="${HOME}/.config/remote-dev"
REMOTE_DEV_BIN_DIR="${HOME}/.local/bin"
REMOTE_DEV_STATE_DIR="${HOME}/.local/state/remote-dev"
REMOTE_DEV_PLATFORM="${REMOTE_DEV_PLATFORM:-generic}"
REMOTE_DEV_DELIVERY="${REMOTE_DEV_DELIVERY:-script}"

log() {
  printf '\033[1;36m[remote-dev]\033[0m %s\n' "$*"
}

success() {
  printf '\033[1;32m[remote-dev]\033[0m %s\n' "$*"
}

warn() {
  printf '\033[1;33m[remote-dev]\033[0m %s\n' "$*" >&2
}

die() {
  printf '\033[1;31m[remote-dev]\033[0m %s\n' "$*" >&2
  exit 1
}

require_supported_host() {
  [[ "${EUID}" -ne 0 ]] || die "Run this installer as your normal user, not root."
  command -v sudo >/dev/null 2>&1 || die "sudo is required."
  [[ -r /etc/os-release ]] || die "Unable to identify this operating system."

  # shellcheck disable=SC1091
  . /etc/os-release
  [[ "${ID:-}" == "ubuntu" ]] || die "Ubuntu is required (found ${ID:-unknown})."

  case "${VERSION_ID:-}" in
    22.04|24.04) ;;
    *) warn "Ubuntu ${VERSION_ID:-unknown} is outside the supported 22.04/24.04 contract." ;;
  esac
}

ensure_user_directories() {
  mkdir -p \
    "${REMOTE_DEV_CONFIG_DIR}" \
    "${REMOTE_DEV_BIN_DIR}" \
    "${REMOTE_DEV_STATE_DIR}" \
    "${HOME}/.cache" \
    "${HOME}/projects"
}

install_default_config() {
  if [[ ! -f "${REMOTE_DEV_CONFIG_DIR}/config.env" ]]; then
    cp "${ROOT_DIR}/config/config.env" "${REMOTE_DEV_CONFIG_DIR}/config.env"
  fi

  if [[ ! -f "${REMOTE_DEV_CONFIG_DIR}/serve-ports" ]]; then
    cp "${ROOT_DIR}/config/serve-ports" "${REMOTE_DEV_CONFIG_DIR}/serve-ports"
  fi
}

profile_at_least() {
  case "${PROFILE}:${1}" in
    core:core|full:core|full:full) return 0 ;;
    *) return 1 ;;
  esac
}

run_module() {
  local name="$1"
  local module="${ROOT_DIR}/install/${name}.sh"
  [[ -f "${module}" ]] || die "Missing installation module: ${module}"
  log "Running ${name} setup..."
  # shellcheck source=/dev/null
  source "${module}"
}

backup_path() {
  local path="$1"
  local backup

  [[ -e "${path}" || -L "${path}" ]] || return 0
  backup="${path}.remote-dev-backup.$(date +%Y%m%d%H%M%S)"
  warn "Backing up ${path} to ${backup}"
  mv "${path}" "${backup}"
}

link_managed_file() {
  local source_path="$1"
  local destination="$2"
  local current_target=""

  if [[ -L "${destination}" ]]; then
    current_target="$(readlink "${destination}")"
    if [[ "${current_target}" == "${source_path}" ]]; then
      return 0
    fi
  fi

  backup_path "${destination}"
  ln -s "${source_path}" "${destination}"
}

install_managed_dotfiles() {
  link_managed_file "${ROOT_DIR}/dotfiles/zshrc" "${HOME}/.zshrc"
  link_managed_file "${ROOT_DIR}/dotfiles/p10k.zsh" "${HOME}/.p10k.zsh"
  link_managed_file "${ROOT_DIR}/dotfiles/tmux.conf" "${HOME}/.tmux.conf"
  touch "${HOME}/.zshrc.local"
}

install_remote_dev_command() {
  link_managed_file "${ROOT_DIR}/bin/remote-dev" "${REMOTE_DEV_BIN_DIR}/remote-dev"
  chmod +x "${ROOT_DIR}/bin/remote-dev"
}

write_install_state() {
  local profile="$1"
  cat > "${REMOTE_DEV_STATE_DIR}/install.env" <<EOF
REMOTE_DEV_PROFILE="${profile}"
REMOTE_DEV_PLATFORM="${REMOTE_DEV_PLATFORM}"
REMOTE_DEV_DELIVERY="${REMOTE_DEV_DELIVERY}"
REMOTE_DEV_INSTALL_DIR="${ROOT_DIR}"
REMOTE_DEV_SOURCE_REF="${REMOTE_DEV_SOURCE_REF:-}"
REMOTE_DEV_INSTALL_DOCKER="${INSTALL_DOCKER:-1}"
REMOTE_DEV_INSTALL_GCLOUD="${INSTALL_GCLOUD:-1}"
REMOTE_DEV_INSTALL_FOUNDRY="${INSTALL_FOUNDRY:-1}"
REMOTE_DEV_INSTALL_CODEX="${INSTALL_CODEX:-1}"
REMOTE_DEV_INSTALL_TAILSCALE="${INSTALL_TAILSCALE:-1}"
REMOTE_DEV_INSTALLED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
EOF
}

print_completion_summary() {
  success "Installation complete."
  printf '\n'
  printf '  Profile:       %s\n' "${PROFILE}"
  printf '  Platform:      %s\n' "${REMOTE_DEV_PLATFORM}"
  printf '  Delivery:      %s\n' "${REMOTE_DEV_DELIVERY}"
  printf '  Install root:  %s\n' "${ROOT_DIR}"
  printf '  Configuration: %s\n' "${REMOTE_DEV_CONFIG_DIR}"
  printf '  Projects:      %s\n' "${HOME}/projects"
  printf '\n'
  printf 'Start a fresh shell:\n'
  printf '  exec zsh -l\n'
  printf '\n'
  printf 'Inspect the environment:\n'
  printf '  remote-dev doctor\n'

  if [[ "${REMOTE_DEV_PLATFORM}" == "exe-dev" ]]; then
    printf '\n'
    printf 'Run development servers on 0.0.0.0 using ports 3000-9999.\n'
    printf 'Open them privately at:\n'
    printf '  https://%s.exe.xyz:<port>/\n' "$(hostname -s)"
  elif [[ "${PROFILE}" == "full" && "${INSTALL_TAILSCALE}" -eq 1 && "${TAILSCALE_UP}" -eq 0 ]]; then
    printf '\n'
    printf 'Connect Tailscale and configure private development ports:\n'
    printf '  remote-dev tailscale\n'
  fi

  if [[ "${PROFILE}" == "full" ]]; then
    printf '\n'
    printf 'Authenticate optional services when needed:\n'
    printf '  gh auth login\n'
    printf '  gcloud auth login\n'
    printf '  codex login\n'
  fi

  if command -v docker >/dev/null 2>&1 && ! id -nG | tr ' ' '\n' | grep -qx docker; then
    printf '\n'
    warn "Docker is installed, but group membership requires a new login session."
  fi
}
