# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

rokkitpokkit is an opinionated Fedora distribution for pocket computers (mobile devices), primarily targeting SDM670/SDM845 Qualcomm platforms. It uses the official Fedora kernel with hardware enablement via akmods, Phosh mobile shell, and an immutable ostree filesystem. Users live-boot via fastboop, then install from the on-device Anaconda web UI.

## Build System

The image is built with **mkosi** (declarative container/OS image builder). The main config is `mkosi.conf` targeting Fedora 44 aarch64.

```bash
# Full image build (requires sudo, produces mkosi.output/rokkitpokkit.ero)
sudo mkosi -f --profile phosh,rawhide,droid-juicer,precompile-akmods,ostree

# Compose casync artifacts (deduplicates and chunks the image)
COMPOSE_ENABLE_PUBLISH=0 COMPOSE_USE_SUDO=1 ./scripts/casync-compose.sh

# Build boot profile channel
BOOT_PROFILE_CLI=./.tools/fastboop-cli ./scripts/bootprofile-channel.sh
```

### mkosi Profiles (mkosi.profiles/)

- **phosh** — Phosh mobile shell
- **ostree** — Immutable ostree filesystem
- **droid-juicer** — Android firmware extraction
- **sdm845-embedded-firmware** — Snapdragon 845 firmware blobs
- **rawhide** — Fedora Rawhide target

## Architecture

### Build Pipeline (CI: `.github/workflows/step_build.yml`)

1. mkosi builds a rootfs → EROFS image (`.ero`)
2. `scripts/casync-compose.sh` deduplicates/chunks → publishes to B2 object storage
3. `scripts/bootprofile-channel.sh` creates boot profiles → publishes to B2 `/channels/`
4. Kubernetes Caddy reverse proxy serves B2 objects at `rokkitpokkit.samcday.com`

### COPR Packages (`copr/`)

Downstream RPM patches for anaconda, anaconda-webui, and droid-juicer. Changes here trigger Packit COPR builds via `.github/workflows/copr-main.yml` (targets Fedora rawhide/44/43/42, aarch64+x86_64).

### Infrastructure (`infra/`)

- **`infra/k8s/`** — Kubernetes manifests (Caddy deployment, HTTPRoute, CORS config). Reconciled by **Flux** from `samcday/infra`, not applied directly from this repo.
- **`infra/tofu/`** — OpenTofu managing B2 credentials, GitHub Actions secrets, and Kubernetes secrets.

## No Test Suite

There is no traditional test infrastructure. Validation happens in CI through casync digest verification, boot profile SHA256 checks, and smoke extraction of artifacts.
