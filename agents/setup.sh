#!/usr/bin/env bash
# Interactive, re-runnable setup of the AI agent stack on this machine:
#   Tailscale login -> GitHub login -> shared agent config -> pinned agent tools ->
#   1Password token -> OpenChamber service on the tailnet -> agent-config install/sync -> doctor.
# Every step is skipped when it is already done.
set -Eeuo pipefail

CONFIG_FILE="${HOME}/.config/remote-dev/config.env"
# shellcheck disable=SC1090
[[ -f "${CONFIG_FILE}" ]] && source "${CONFIG_FILE}"

AGENT_CONFIG_REPOSITORY="${REMOTE_DEV_AGENT_CONFIG_REPOSITORY:-chrismaree/open-code-config}"
AGENT_CONFIG_DIR="${REMOTE_DEV_AGENT_CONFIG_DIR:-${HOME}/projects/open-code-config}"
OPENCHAMBER_PORT="${REMOTE_DEV_OPENCHAMBER_PORT:-3000}"
OP_TOKEN_FILE="${HOME}/.config/op/agent-config-token"
MACHINE="${REMOTE_DEV_AGENT_MACHINE_NAME:-$(hostname -s)}"

log() { printf '\033[1;36m[remote-dev/agents]\033[0m %s\n' "$*"; }
ok() { printf '\033[1;32m[remote-dev/agents]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[remote-dev/agents]\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31m[remote-dev/agents]\033[0m %s\n' "$*" >&2; exit 1; }

[[ "${EUID}" -ne 0 ]] || die "Run as your normal user, not root."
for required in tailscale gh op gitleaks jq python3; do
  command -v "${required}" >/dev/null 2>&1 || die "${required} is missing. Run: remote-dev setup (installs the agent prerequisites)."
done
python3 -c 'import sys; sys.exit(sys.version_info < (3, 11))' || die "Python 3.11+ is required (Ubuntu 24.04 provides it)."

export NVM_DIR="${HOME}/.nvm"
# shellcheck disable=SC1091
source "${NVM_DIR}/nvm.sh"
nvm use default >/dev/null
NODE_BIN="$(dirname "$(command -v node)")"

step_tailscale() {
  if tailscale status >/dev/null 2>&1; then
    ok "Tailscale connected as $(tailscale status --self --json | jq -r '.Self.DNSName' | sed 's/\.$//')"
    return
  fi
  log "Log in to Tailscale (open the link that follows)..."
  sudo tailscale up --hostname "${MACHINE}"
}

step_github() {
  if ! gh auth status >/dev/null 2>&1; then
    log "Log in to GitHub with the account this machine should use..."
    gh auth login --hostname github.com --git-protocol https --web
  fi
  gh auth setup-git >/dev/null
  if [[ -z "$(git config --global user.name || true)" ]]; then
    git config --global user.name "$(gh api user --jq '.name // .login')"
    git config --global user.email "$(gh api user --jq '"\(.id)+\(.login)@users.noreply.github.com"')"
  fi
  ok "GitHub: $(gh api user --jq .login)"
}

step_config_repo() {
  if [[ -d "${AGENT_CONFIG_DIR}/.git" ]]; then
    git -C "${AGENT_CONFIG_DIR}" pull --ff-only --quiet || warn "Could not fast-forward ${AGENT_CONFIG_DIR}; leaving it as is."
  else
    log "Cloning ${AGENT_CONFIG_REPOSITORY}..."
    mkdir -p "$(dirname "${AGENT_CONFIG_DIR}")"
    gh repo clone "${AGENT_CONFIG_REPOSITORY}" "${AGENT_CONFIG_DIR}" -- --quiet ||
      die "Cannot clone ${AGENT_CONFIG_REPOSITORY}. Give $(gh api user --jq .login) access to it and rerun."
  fi
  ok "Agent config at ${AGENT_CONFIG_DIR}"
}

step_tools() {
  local versions="${AGENT_CONFIG_DIR}/versions.json" packages=() package version installed
  while IFS=$'\t' read -r package version; do
    installed="$(npm ls -g --depth=0 --json 2>/dev/null | jq -r --arg p "${package}" '.dependencies[$p].version // empty')"
    [[ "${installed}" == "${version}" ]] || packages+=("${package}@${version}")
  done < <(jq -r '.npm | to_entries[] | "\(.key)\t\(.value)"' "${versions}")
  if ((${#packages[@]})); then
    log "Installing ${packages[*]}..."
    npm install --global "${packages[@]}"
  fi
  ok "Agent tools: opencode $(opencode --version 2>/dev/null | head -1), openchamber $(openchamber --version 2>/dev/null | head -1)"
  if [[ "$(dpkg --print-architecture)" == "amd64" ]] && ! command -v google-chrome >/dev/null 2>&1; then
    log "Installing Chrome for the Playwright MCP..."
    npx -y playwright install --with-deps chrome
  fi
}

step_op_token() {
  if [[ ! -s "${OP_TOKEN_FILE}" ]]; then
    log "Paste the 1Password service-account token for the agent-config vault (input hidden), then press Enter."
    log "Use the read-only token for dev boxes."
    local token
    read -rs token
    printf '\n'
    [[ -n "${token}" ]] || die "No token entered."
    install -d -m 700 "$(dirname "${OP_TOKEN_FILE}")"
    (umask 077 && printf '%s' "${token}" > "${OP_TOKEN_FILE}")
    unset token
  fi
  OP_SERVICE_ACCOUNT_TOKEN="$(cat "${OP_TOKEN_FILE}")" op vault get agent-config >/dev/null 2>&1 ||
    die "The token in ${OP_TOKEN_FILE} cannot read the agent-config vault. Replace the file and rerun."
  ok "1Password token can read the agent-config vault"
}

step_openchamber_service() {
  local env_file="${HOME}/.config/openchamber/service.env" unit=/etc/systemd/system/openchamber.service tmp
  mkdir -p "${HOME}/.config/openchamber" "${HOME}/projects"
  if [[ ! -s "${env_file}" ]]; then
    (umask 077 && printf 'OPENCHAMBER_UI_PASSWORD=%s\n' "$(openssl rand -base64 24 | tr -d '/+=')" > "${env_file}")
    log "Generated an OpenChamber UI password in ${env_file}"
  fi
  tmp="$(mktemp)"
  cat > "${tmp}" <<EOF
[Unit]
Description=OpenChamber (OpenCode web UI)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${USER}
WorkingDirectory=${HOME}/projects
Environment=HOME=${HOME}
Environment=PATH=${NODE_BIN}:${HOME}/.local/bin:${HOME}/.foundry/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Environment=OPENCHAMBER_HOST=127.0.0.1
EnvironmentFile=${env_file}
ExecStart=${NODE_BIN}/openchamber serve --port ${OPENCHAMBER_PORT} --host 127.0.0.1 --foreground
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
  if ! sudo cmp -s "${tmp}" "${unit}"; then
    sudo install -m 0644 "${tmp}" "${unit}"
    sudo systemctl daemon-reload
  fi
  rm -f "${tmp}"
  sudo systemctl enable --now openchamber.service >/dev/null
  if ! tailscale serve status 2>/dev/null | grep -q "127.0.0.1:${OPENCHAMBER_PORT}"; then
    sudo tailscale serve --bg "http://127.0.0.1:${OPENCHAMBER_PORT}" >/dev/null
  fi
  for _ in $(seq 1 30); do
    [[ -d "${HOME}/.config/openchamber" && -f "${HOME}/.config/openchamber/settings.json" ]] && break
    sleep 1
  done
  ok "OpenChamber at https://$(tailscale status --self --json | jq -r '.Self.DNSName' | sed 's/\.$//')/"
}

step_agent_config() {
  local cli="${AGENT_CONFIG_DIR}/bin/agent-config"
  "${cli}" install --host "${MACHINE}"
  if [[ -z "$(git -C "${AGENT_CONFIG_DIR}" config user.signingkey || true)" ]]; then
    "${cli}" signing "${MACHINE}"
    warn "Add the line above to allowed_signers from an admin machine so this machine's commits are accepted."
  fi
  "${cli}" schedule enable
  sudo systemctl restart openchamber.service
  ok "Agent config installed; OpenChamber restarted"
}

step_tailscale
step_github
step_config_repo
step_tools
step_op_token
step_openchamber_service
step_agent_config

log "Remaining items (if any):"
"${AGENT_CONFIG_DIR}/bin/agent-config" doctor || true
