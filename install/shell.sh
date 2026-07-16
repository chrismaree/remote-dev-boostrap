#!/usr/bin/env bash

OH_MY_ZSH_DIR="${HOME}/.oh-my-zsh"
ZSH_CUSTOM_DIR="${OH_MY_ZSH_DIR}/custom"

if [[ ! -d "${OH_MY_ZSH_DIR}/.git" ]]; then
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
    "" --unattended
fi

mkdir -p "${ZSH_CUSTOM_DIR}/themes" "${ZSH_CUSTOM_DIR}/plugins"

if [[ ! -d "${ZSH_CUSTOM_DIR}/themes/powerlevel10k/.git" ]]; then
  git clone --depth 1 \
    https://github.com/romkatv/powerlevel10k.git \
    "${ZSH_CUSTOM_DIR}/themes/powerlevel10k"
fi

if [[ ! -d "${ZSH_CUSTOM_DIR}/plugins/zsh-autosuggestions/.git" ]]; then
  git clone --depth 1 \
    https://github.com/zsh-users/zsh-autosuggestions \
    "${ZSH_CUSTOM_DIR}/plugins/zsh-autosuggestions"
fi

if [[ ! -d "${ZSH_CUSTOM_DIR}/plugins/zsh-syntax-highlighting/.git" ]]; then
  git clone --depth 1 \
    https://github.com/zsh-users/zsh-syntax-highlighting.git \
    "${ZSH_CUSTOM_DIR}/plugins/zsh-syntax-highlighting"
fi

if [[ "${SHELL:-}" != "$(command -v zsh)" ]]; then
  if ! sudo chsh -s "$(command -v zsh)" "${USER}"; then
    warn "Could not change the account's default shell. Use 'exec zsh -l' manually."
  fi
fi
