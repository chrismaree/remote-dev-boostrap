#!/usr/bin/env bash

export PATH="${HOME}/.foundry/bin:${PATH}"

if ! command -v foundryup >/dev/null 2>&1; then
  curl -L https://foundry.paradigm.xyz | bash
fi

export PATH="${HOME}/.foundry/bin:${PATH}"
foundryup
