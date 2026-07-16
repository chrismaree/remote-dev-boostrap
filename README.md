# Remote Dev Bootstrap

A personal, repeatable Ubuntu development environment for disposable VMs and
hosted workspaces.

The default installation gives you a comfortable shell and the tools needed for
modern Python, Node.js, container, cloud, smart-contract, and AI-assisted
development. It is designed to be safe to run more than once and deliberately
does not copy credentials, private keys, or project-specific configuration.

## Recommended: exe.dev setup script

For the first version of this workflow, use the setup script with exe.dev's
standard `exeuntu` image. This keeps iteration simple while exe.dev provides the
private HTTPS proxy and the base image provides Docker, Codex, and the VM
runtime.

Create one VM with the setup script:

```bash
curl -fsSL \
  https://raw.githubusercontent.com/chrismaree/remote-dev-boostrap/master/exe-dev/setup.sh \
  | ssh exe.dev new --name my-devbox --setup-script /dev/stdin
```

Or make it the default for future VMs:

```bash
curl -fsSL \
  https://raw.githubusercontent.com/chrismaree/remote-dev-boostrap/master/exe-dev/setup.sh \
  | ssh exe.dev defaults write dev.exe new.setup-script
```

The exe.dev preset installs the full personal toolchain but intentionally does
not install or configure Tailscale, reinstall Docker, or replace the Codex
binary supplied by `exeuntu`.

After the VM is ready:

```bash
ssh my-devbox.exe.xyz
remote-dev doctor
exec zsh -l
```

Run web applications on `0.0.0.0` using ports `3000` through `9999`:

```bash
npm run dev -- --host 0.0.0.0
python -m uvicorn app:app --host 0.0.0.0 --port 9000
```

They are privately available to users with access to the VM:

```text
https://my-devbox.exe.xyz:3000/
https://my-devbox.exe.xyz:9000/
```

Next.js and Vite may also require the exe.dev hostname in
`allowedDevOrigins` or `server.allowedHosts`.

To check the toolchain and proxy behavior on a VM:

```bash
~/.local/share/remote-dev-bootstrap/exe-dev/smoke-test.sh
~/.local/share/remote-dev-bootstrap/exe-dev/test-server.sh
```

The test server binds port `3000` by default. Set `PORT=9000` to try another
proxied port.

## Generic Ubuntu quick start

On a fresh Ubuntu 22.04 or 24.04 machine:

```bash
curl -fsSL \
  https://raw.githubusercontent.com/chrismaree/remote-dev-boostrap/master/bootstrap.sh \
  | bash
```

For a reproducible installation, pin a release or commit:

```bash
curl -fsSL \
  https://raw.githubusercontent.com/chrismaree/remote-dev-boostrap/v0.1.0/bootstrap.sh \
  | REMOTE_DEV_REF=v0.1.0 bash
```

The installer uses `sudo` for operating-system packages and installs personal
configuration into your user account. Do not run the curl command with `sudo`.

After installation, start a new login shell:

```bash
exec zsh -l
```

Powerlevel10k looks best when your local terminal uses a Nerd Font. If your
current terminal already renders your local Powerlevel10k prompt correctly, no
additional font setup is needed on the remote machine.

Then connect the machine to Tailscale:

```bash
remote-dev tailscale
```

And authenticate the tools you want to use:

```bash
gh auth login
gcloud auth login
codex login
```

## What gets installed

The default `full` profile includes:

- Ubuntu build and troubleshooting tools
- Zsh, Oh My Zsh, Powerlevel10k, autosuggestions, and syntax highlighting
- tmux with a managed, mouse-friendly configuration
- Python 3.12 as the default user Python
- Python 3.11 as an additional compatibility runtime
- uv for Python versions, virtual environments, packages, and tools
- NVM with Node.js 22.19.0
- Yarn 1.22.22
- Docker Engine, Buildx, and Docker Compose
- GitHub CLI
- Google Cloud CLI and the GKE authentication plugin
- Foundry (`forge`, `cast`, `anvil`, and `chisel`)
- Codex CLI
- Tailscale
- PostgreSQL, Redis, and SQLite client tools

The environment is generic. It does not clone application repositories, install
their dependencies, copy `.env` files, or configure cloud projects.

## Profiles

Run a smaller installation when you do not need the complete toolchain:

```bash
# Shell, common packages, Python, and Node.js
curl -fsSL https://raw.githubusercontent.com/chrismaree/remote-dev-boostrap/master/bootstrap.sh \
  | bash -s -- --profile core

# Shell and common packages only
curl -fsSL https://raw.githubusercontent.com/chrismaree/remote-dev-boostrap/master/bootstrap.sh \
  | bash -s -- --profile minimal
```

Profiles:

| Profile | Includes |
|---|---|
| `minimal` | Ubuntu packages, shell, dotfiles, and helper command |
| `core` | `minimal` plus Python and Node.js |
| `full` | `core` plus Docker, GitHub CLI, gcloud, Foundry, Codex, and Tailscale |

The exe.dev preset selects `full` while skipping components already supplied
by `exeuntu` or unnecessary behind the exe.dev proxy:

```bash
bash install.sh --preset exe-dev
```

Individual full-profile components can be omitted:

```bash
bash install.sh --profile full --without-docker --without-gcloud
```

Available flags:

```text
--preset generic|exe-dev
--profile minimal|core|full
--without-docker
--without-gcloud
--without-foundry
--without-codex
--without-tailscale
--tailscale-up
```

## Tailscale

Tailscale is part of the generic Ubuntu path, not the recommended exe.dev path.

`remote-dev tailscale` authenticates the machine and then configures private
Tailscale Serve endpoints for the standard development ports:

```text
3000
5173
8000
8080
9000
```

Applications should continue listening on `127.0.0.1`. Tailscale Serve proxies
the configured private HTTPS endpoints to those local services:

```text
https://<machine>.<tailnet>.ts.net:3000
https://<machine>.<tailnet>.ts.net:9000
```

Inspect or change the ports with:

```bash
remote-dev ports
remote-dev serve 3000 8000 9000
remote-dev unserve 5173
```

The persistent port list lives at:

```text
~/.config/remote-dev/serve-ports
```

### Automated Tailscale provisioning

For disposable infrastructure, inject a one-off, tagged, ephemeral Tailscale
auth key through the hosting provider:

```bash
export TS_AUTH_KEY="injected-by-your-provider"
remote-dev tailscale
unset TS_AUTH_KEY
```

The helper writes the key to a temporary `0600` file, passes the file to
Tailscale, and removes it. The key is never written to the repository or a shell
configuration file.

Optional Tailscale settings can be changed in:

```text
~/.config/remote-dev/config.env
```

For example:

```bash
REMOTE_DEV_TAILSCALE_HOSTNAME="dev-api-01"
REMOTE_DEV_TAILSCALE_TAGS="tag:development"
REMOTE_DEV_ENABLE_TAILSCALE_SSH="0"
```

Leave `REMOTE_DEV_TAILSCALE_TAGS` empty unless your tailnet policy defines and
permits the tag.

## Codex remote control

After `codex login`, use:

```bash
remote-dev codex start
remote-dev codex pair
remote-dev codex stop
```

The helper delegates directly to `codex remote-control`.

## Python workflow

Python is managed with uv:

```bash
python --version
python3.11 --version
python3.12 --version

uv venv
source .venv/bin/activate
uv pip install -r requirements.txt
```

The bootstrap leaves Ubuntu's system Python untouched. User-facing `python` and
`python3` executables come from uv through `~/.local/bin`.

## Node.js workflow

NVM is loaded automatically by Zsh. The default runtime is configurable:

```bash
nvm current
nvm install 24
nvm use 24
```

The bootstrap default is stored in `~/.config/remote-dev/config.env`:

```bash
REMOTE_DEV_NODE_VERSION="22.19.0"
```

## Shell customization

The managed shell configuration is linked from the installed repository.
Machine-specific additions belong in:

```text
~/.zshrc.local
```

This keeps personal aliases or environment-specific settings separate from the
updatable bootstrap files. Never place long-lived secrets in `.zshrc.local`;
prefer a password manager, workload identity, or the hosting provider's secret
injection.

Existing `.zshrc`, `.p10k.zsh`, and `.tmux.conf` files are backed up before the
bootstrap replaces them with managed links.

## Helper command

```text
remote-dev doctor        Show installed tools and pending actions
remote-dev update        Pull bootstrap updates and rerun the installer
remote-dev setup         Rerun the installed bootstrap
remote-dev tailscale     Authenticate Tailscale and configure standard ports
remote-dev serve [...]   Configure private Serve endpoints
remote-dev unserve [...] Remove private Serve endpoints
remote-dev ports         Show configured development ports
remote-dev codex ...     Manage Codex remote control
remote-dev shell         Start a fresh Zsh login shell
```

## Updating

```bash
remote-dev update
```

This performs a fast-forward-only Git update and reruns the currently selected
profile. Local machine customization remains in `.zshrc.local` and
`~/.config/remote-dev/config.env`.

An installation baked into the experimental Docker image is immutable.
`remote-dev update` will tell you to build or select a newer image instead.

## Experimental exe.dev Docker image

`Dockerfile.exe-dev` is a future-facing optimization built on the official
`ghcr.io/boldsoftware/exeuntu` base. It bakes the same exe.dev preset into the
image so VM creation does not need to repeat the full package installation.

This is intentionally not the starting workflow. First use the setup script,
learn which tools belong in the permanent image, then publish a versioned image.

Build locally when you are ready to experiment:

```bash
docker build -f Dockerfile.exe-dev \
  -t ghcr.io/chrismaree/remote-dev-bootstrap:experimental .
```

The repository also includes a manual-only GitHub Actions workflow. Running
`Publish experimental exe.dev image` publishes the selected tag and a commit
SHA tag to GitHub Container Registry. It does not run automatically on pushes.

Create an exe.dev VM from a published image:

```bash
ssh exe.dev new \
  --name my-image-devbox \
  --image ghcr.io/chrismaree/remote-dev-bootstrap:experimental
```

## Security boundaries

This repository intentionally does not:

- copy or generate SSH private keys
- disable SSH host-key checking
- copy project `.env` files
- authenticate GitHub, Google Cloud, Codex, or Tailscale without your action or
  an explicitly supplied temporary credential
- select a Google Cloud project
- open development ports on the public network
- install a public ingress tunnel
- clone or configure application repositories

Membership in the Docker group effectively grants root-level control of the
machine. The bootstrap adds the current user to that group for convenience on a
disposable development host; a new login session is required before it takes
effect.

## Repository layout

```text
bootstrap.sh          Curl-friendly repository installer
install.sh            Idempotent profile orchestrator
bin/remote-dev        Day-to-day helper command
exe-dev/              exe.dev setup and smoke-test scripts
Dockerfile.exe-dev    Experimental prebuilt exe.dev image
config/               Default user configuration
dotfiles/             Managed Zsh, Powerlevel10k, and tmux configuration
install/              Individual installation modules
lib/common.sh         Shared installer functions
```

## Supported systems

The bootstrap currently targets:

- Ubuntu 22.04 LTS
- Ubuntu 24.04 LTS
- x86_64 / amd64
- arm64 / aarch64

Other Debian-derived systems may work, but are not currently a supported
contract.
