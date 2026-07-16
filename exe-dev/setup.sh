#!/usr/bin/env bash
set -Eeuo pipefail

REPOSITORY="${REMOTE_DEV_REPOSITORY:-https://github.com/chrismaree/remote-dev-boostrap.git}"
REF="${REMOTE_DEV_REF:-master}"
RAW_BASE="${REMOTE_DEV_RAW_BASE:-https://raw.githubusercontent.com/chrismaree/remote-dev-boostrap/${REF}}"
BOOTSTRAP_URL="${REMOTE_DEV_BOOTSTRAP_URL:-${RAW_BASE}/bootstrap.sh}"

log() {
  printf '\033[1;36m[remote-dev/exe.dev]\033[0m %s\n' "$*"
}

die() {
  printf '\033[1;31m[remote-dev/exe.dev]\033[0m %s\n' "$*" >&2
  exit 1
}

[[ "${EUID}" -ne 0 ]] || die "exe.dev setup must run as the exedev login user."
[[ "${EXEUNTU:-0}" == "1" ]] || log "Warning: EXEUNTU is not set; continuing on a compatible Ubuntu host."
command -v curl >/dev/null 2>&1 || die "curl is required."

bootstrap_file="$(mktemp)"
trap 'rm -f "${bootstrap_file}"' EXIT

log "Downloading the bootstrap at ${REF}..."
curl -fsSL "${BOOTSTRAP_URL}" -o "${bootstrap_file}"
chmod 0700 "${bootstrap_file}"

export REMOTE_DEV_REPOSITORY="${REPOSITORY}"
export REMOTE_DEV_REF="${REF}"
export REMOTE_DEV_PLATFORM="exe-dev"
export REMOTE_DEV_DELIVERY="script"

log "Installing the exe.dev preset..."
bash "${bootstrap_file}" --preset exe-dev
