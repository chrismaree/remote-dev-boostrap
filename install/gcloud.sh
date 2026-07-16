#!/usr/bin/env bash

sudo install -m 0755 -d /etc/apt/keyrings

if [[ ! -f /etc/apt/keyrings/cloud.google.gpg ]]; then
  curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg |
    gpg --dearmor |
    sudo tee /etc/apt/keyrings/cloud.google.gpg >/dev/null
fi

cat <<'EOF' | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list >/dev/null
deb [signed-by=/etc/apt/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main
EOF

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  google-cloud-cli \
  google-cloud-cli-gke-gcloud-auth-plugin
