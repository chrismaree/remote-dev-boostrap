#!/usr/bin/env bash
set -Eeuo pipefail

REPOSITORY="${REMOTE_DEV_REPOSITORY:-https://github.com/chrismaree/remote-dev-boostrap.git}"
REF="${REMOTE_DEV_REF:-master}"
INSTALL_DIR="${REMOTE_DEV_INSTALL_DIR:-$HOME/.local/share/remote-dev-bootstrap}"

log() {
  printf '\033[1;36m[remote-dev]\033[0m %s\n' "$*"
}

die() {
  printf '\033[1;31m[remote-dev]\033[0m %s\n' "$*" >&2
  exit 1
}

if [[ "${EUID}" -eq 0 ]]; then
  die "Run the bootstrap as a normal sudo-capable user, not as root."
fi

if [[ ! -r /etc/os-release ]]; then
  die "Unable to identify this operating system."
fi

# shellcheck disable=SC1091
. /etc/os-release
if [[ "${ID:-}" != "ubuntu" ]]; then
  die "This bootstrap currently supports Ubuntu only (found ${ID:-unknown})."
fi

case "${VERSION_ID:-}" in
  22.04|24.04) ;;
  *) log "Warning: Ubuntu ${VERSION_ID:-unknown} is not part of the tested support contract." ;;
esac

if ! command -v sudo >/dev/null 2>&1; then
  die "sudo is required. Install it or run inside an image that provides it."
fi

if ! command -v git >/dev/null 2>&1; then
  log "Installing Git so the bootstrap can install itself..."
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y git ca-certificates curl
fi

mkdir -p "$(dirname "${INSTALL_DIR}")"

if [[ -d "${INSTALL_DIR}/.git" ]]; then
  log "Updating existing installation in ${INSTALL_DIR}..."
  if git -C "${INSTALL_DIR}" ls-remote --exit-code --heads origin "${REF}" >/dev/null 2>&1; then
    git -C "${INSTALL_DIR}" fetch --depth 1 origin \
      "${REF}:refs/remotes/origin/${REF}"
    git -C "${INSTALL_DIR}" checkout -B "${REF}" "origin/${REF}"
    git -C "${INSTALL_DIR}" branch --set-upstream-to="origin/${REF}" "${REF}"
  else
    git -C "${INSTALL_DIR}" fetch --depth 1 origin "${REF}"
    git -C "${INSTALL_DIR}" checkout --detach FETCH_HEAD
  fi
else
  if [[ -e "${INSTALL_DIR}" ]]; then
    backup="${INSTALL_DIR}.backup.$(date +%Y%m%d%H%M%S)"
    log "Moving existing ${INSTALL_DIR} to ${backup}..."
    mv "${INSTALL_DIR}" "${backup}"
  fi

  log "Installing ${REPOSITORY} at ${REF}..."
  git clone --depth 1 --branch "${REF}" "${REPOSITORY}" "${INSTALL_DIR}" 2>/dev/null || {
    git clone --depth 1 "${REPOSITORY}" "${INSTALL_DIR}"
    git -C "${INSTALL_DIR}" fetch --depth 1 origin "${REF}"
    git -C "${INSTALL_DIR}" checkout --detach FETCH_HEAD
  }
fi

log "Launching installer..."
export REMOTE_DEV_SOURCE_REF="${REF}"
exec "${INSTALL_DIR}/install.sh" "$@"
