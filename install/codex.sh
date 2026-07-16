#!/usr/bin/env bash

export NVM_DIR="${HOME}/.nvm"
# shellcheck disable=SC1091
source "${NVM_DIR}/nvm.sh"
nvm use default >/dev/null

npm install --global @openai/codex
