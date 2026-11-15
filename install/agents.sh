#!/usr/bin/env bash
# Non-interactive prerequisites for the AI agent stack. `remote-dev agents` finishes the setup
# (logins, pinned OpenCode/OpenChamber/Codex/Claude Code, shared agent config, OpenChamber service).

# shellcheck disable=SC1090
source "${REMOTE_DEV_CONFIG_DIR}/config.env"

# Tailscale: OpenChamber and the private model providers are reached over the tailnet.
if ! command -v tailscale >/dev/null 2>&1; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi
sudo systemctl enable --now tailscaled >/dev/null 2>&1 || true

# 1Password CLI: agent secrets are pulled with a vault-scoped service-account token.
if ! command -v op >/dev/null 2>&1; then
  architecture="$(dpkg --print-architecture)"
  if [[ ! -f /usr/share/keyrings/1password-archive-keyring.gpg ]]; then
    curl -fsSL https://downloads.1password.com/linux/keys/1password.asc |
      sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
  fi
  printf 'deb [arch=%s signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/%s stable main\n' \
    "${architecture}" "${architecture}" | sudo tee /etc/apt/sources.list.d/1password.list >/dev/null
  sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22 /usr/share/debsig/keyrings/AC2D62742012EA22
  curl -fsSL https://downloads.1password.com/linux/debian/debsig/1password.pol |
    sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol >/dev/null
  if [[ ! -f /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg ]]; then
    curl -fsSL https://downloads.1password.com/linux/keys/1password.asc |
      sudo gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg
  fi
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y 1password-cli
fi

# gitleaks: the agent config repo scans every commit for secrets.
GITLEAKS_VERSION="${REMOTE_DEV_GITLEAKS_VERSION:-8.30.1}"
if [[ "$(gitleaks version 2>/dev/null || true)" != "${GITLEAKS_VERSION}" ]]; then
  case "$(dpkg --print-architecture)" in
    amd64) gitleaks_arch="x64" ;;
    arm64) gitleaks_arch="arm64" ;;
    *) die "Unsupported architecture for gitleaks: $(dpkg --print-architecture)" ;;
  esac
  gitleaks_dir="$(mktemp -d)"
  curl -fsSL "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_${gitleaks_arch}.tar.gz" |
    tar -xz -C "${gitleaks_dir}" gitleaks
  sudo install -m 0755 "${gitleaks_dir}/gitleaks" /usr/local/bin/gitleaks
  rm -rf "${gitleaks_dir}"
fi
