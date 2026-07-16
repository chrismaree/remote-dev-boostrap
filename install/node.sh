#!/usr/bin/env bash

# shellcheck disable=SC1090
source "${REMOTE_DEV_CONFIG_DIR}/config.env"

export NVM_DIR="${HOME}/.nvm"

if [[ ! -s "${NVM_DIR}/nvm.sh" ]]; then
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh |
    PROFILE=/dev/null bash
fi

# shellcheck disable=SC1091
source "${NVM_DIR}/nvm.sh"

NODE_VERSION="${REMOTE_DEV_NODE_VERSION:-22.19.0}"
nvm install "${NODE_VERSION}"
nvm alias default "${NODE_VERSION}"
nvm use default

if corepack enable && corepack prepare yarn@1.22.22 --activate; then
  :
else
  warn "Corepack could not activate Yarn; installing Yarn through npm instead."
  npm install --global --force yarn@1.22.22
fi
