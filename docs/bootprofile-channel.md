# Boot Profile Channel Publisher

Boot profile channel publication is independent from casync compose publication.

## Object layout

Boot profile channel objects are published under `channels/`:

- `channels/builds/<run>-<attempt>-<sha>.bootpro` - immutable boot profile binary per build
- `channels/stable.bootpro` - mutable stable boot profile pointer updated by pushes to `main`

## CI behavior

`step_build.yml` runs `scripts/bootprofile-channel.sh` after `scripts/casync-compose.sh` completes.

`step_build.yml` also downloads `fastboop-cli` `v0.0.1-rc.11` from fastboop release
artifacts, verifies the SHA256 digest, and passes it to
`scripts/bootprofile-channel.sh` via `BOOT_PROFILE_CLI`.

The boot profile script:

1. Selects boot profile rootfs source:
   - uses casync index + chunk-store URLs when provided
   - otherwise falls back to a local EROFS file path
2. Writes boot profile artifacts to `mkosi.output/bootprofile/`:
   - `rokkitpokkit.bootpro.json`
   - `rokkitpokkit.bootpro`
   - `rokkitpokkit.bootpro.sha256`
   - includes extra cmdline: `selinux=0 init_on_alloc=0 fw_devlink=permissive deferred_probe_timeout=60`
3. Publishes the immutable boot profile object when publish is enabled.
4. Updates `channels/stable.bootpro` on pushes to `main`.

Boot profile compilation is delegated to `fastboop-cli`:

- `BOOT_PROFILE_CLI` defaults to `fastboop-cli` from `PATH`.
- CI sets `BOOT_PROFILE_CLI` to a pinned `v0.0.1-rc.11` release artifact.

Publish uses the same B2 credentials as compose publication:

- `B2_ACCESS_KEY_ID`
- `B2_SECRET_ACCESS_KEY`
- `B2_BUCKET`
- `B2_ENDPOINT_URL`

## Local dry-run

```bash
FASTBOOP_CLI_VERSION=v0.0.1-rc.11

case "$(uname -m)" in
  aarch64|arm64)
    FASTBOOP_CLI_TARGET=aarch64-unknown-linux-musl
    FASTBOOP_CLI_SHA256=a2b60001ab564d298f4c3f5475ea165a743afc0e46705cf9b2bb787f5be92456
    ;;
  x86_64|amd64)
    FASTBOOP_CLI_TARGET=x86_64-unknown-linux-musl
    FASTBOOP_CLI_SHA256=f80a25fc0209b6c8a7f0ca39a9b9f06e69107ba9adc4485d4ef621a9118e0e1f
    ;;
  *)
    echo "unsupported architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

mkdir -p .tools
curl -fsSL "https://github.com/samcday/fastboop/releases/download/${FASTBOOP_CLI_VERSION}/fastboop-cli-${FASTBOOP_CLI_TARGET}.tar.gz" \
  -o ".tools/fastboop-cli-${FASTBOOP_CLI_TARGET}.tar.gz"
echo "${FASTBOOP_CLI_SHA256}  .tools/fastboop-cli-${FASTBOOP_CLI_TARGET}.tar.gz" | sha256sum -c -
tar -xzf ".tools/fastboop-cli-${FASTBOOP_CLI_TARGET}.tar.gz" -C .tools
chmod +x .tools/fastboop-cli

sudo mkosi -f --profile erofs-lz4,phosh,sdm845-embedded-firmware,precompile-akmods,ostree
BOOT_PROFILE_CLI=./.tools/fastboop-cli \
BOOT_PROFILE_ENABLE_PUBLISH=0 \
BOOT_PROFILE_SOURCE_FILE=./mkosi.output/rokkitpokkit.ero \
./scripts/bootprofile-channel.sh
```

## Local publish test

```bash
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export BOOT_PROFILE_BUCKET=...
export BOOT_PROFILE_ENDPOINT_URL=...
export BOOT_PROFILE_PUBLIC_BASE_URL=https://rokkitpokkit.samcday.com
export BOOT_PROFILE_ENABLE_PUBLISH=1
export BOOT_PROFILE_SOURCE_CASYNC_INDEX=https://rokkitpokkit.samcday.com/casync/compose-<build>.caibx
export BOOT_PROFILE_SOURCE_CASYNC_CHUNK_STORE=https://rokkitpokkit.samcday.com/casync/default.castr/
export BOOT_PROFILE_CLI=./.tools/fastboop-cli
./scripts/bootprofile-channel.sh
```
