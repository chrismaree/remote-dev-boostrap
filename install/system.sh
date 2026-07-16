#!/usr/bin/env bash

export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  software-properties-common

sudo add-apt-repository -y universe
sudo apt-get update

sudo apt-get install -y \
  apt-transport-https \
  bat \
  btop \
  build-essential \
  clang \
  cmake \
  command-not-found \
  direnv \
  dnsutils \
  fd-find \
  fzf \
  git \
  git-lfs \
  htop \
  iproute2 \
  jq \
  less \
  libbz2-dev \
  libffi-dev \
  liblzma-dev \
  libncursesw5-dev \
  libpq-dev \
  libreadline-dev \
  libsqlite3-dev \
  libssl-dev \
  lsof \
  make \
  nano \
  net-tools \
  netcat-openbsd \
  openssh-client \
  openssl \
  pipx \
  pkg-config \
  postgresql-client \
  python3 \
  python3-dev \
  python3-pip \
  python3-venv \
  redis-tools \
  ripgrep \
  rsync \
  shellcheck \
  sqlite3 \
  tar \
  tk-dev \
  tmux \
  tree \
  unzip \
  uuid-dev \
  vim \
  wget \
  xz-utils \
  xdg-utils \
  zip \
  zlib1g-dev \
  zsh

git lfs install --skip-repo >/dev/null 2>&1 || true

if command -v fdfind >/dev/null 2>&1 && [[ ! -e "${REMOTE_DEV_BIN_DIR}/fd" ]]; then
  ln -s "$(command -v fdfind)" "${REMOTE_DEV_BIN_DIR}/fd"
fi

if command -v batcat >/dev/null 2>&1 && [[ ! -e "${REMOTE_DEV_BIN_DIR}/bat" ]]; then
  ln -s "$(command -v batcat)" "${REMOTE_DEV_BIN_DIR}/bat"
fi
