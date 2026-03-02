# Boot Profile Channel Publisher

Boot profile channel publication is independent from casync compose publication.

## Object layout

All boot profile channel objects live under the existing `live-pocket-fedora/` prefix:

- `live-pocket-fedora/bootprofiles/<run>-<attempt>-<sha>.bootpro` - immutable boot profile binary per build
- `live-pocket-fedora/channels/stable.bootpro` - mutable stable boot profile pointer updated by pushes to `main`

## CI behavior

`step_build.yml` runs `scripts/bootprofile-channel.sh` after `scripts/casync-compose.sh` completes.

`step_build.yml` also builds a fresh `fastboop-cli` snapshot from `fastboop` `main` and
passes it to `scripts/bootprofile-channel.sh` via `BOOT_PROFILE_CLI`.

The boot profile script:

1. Selects boot profile rootfs source:
   - uses casync index + chunk-store URLs when provided
   - otherwise falls back to a local EROFS file path
2. Writes boot profile artifacts to `mkosi.output/bootprofile/`:
   - `live-pocket-fedora.bootpro.json`
   - `live-pocket-fedora.bootpro`
   - `live-pocket-fedora.bootpro.sha256`
3. Publishes the immutable boot profile object when publish is enabled.
4. Updates `channels/stable.bootpro` on pushes to `main`.

Boot profile compilation is delegated to `fastboop-cli`:

- `BOOT_PROFILE_CLI` defaults to `fastboop-cli` from `PATH`.
- CI sets `BOOT_PROFILE_CLI` to the snapshot binary built from `fastboop` `main`.

Publish uses the same R2 credentials as compose publication:

- `R2_ACCESS_KEY_ID`
- `R2_SECRET_ACCESS_KEY`
- `R2_BUCKET`
- `R2_ENDPOINT_URL`

## Local dry-run

```bash
git -C ~/src/fastboop fetch origin main
git -C ~/src/fastboop checkout main
git -C ~/src/fastboop pull --ff-only
cargo build --release --locked -p fastboop-cli --manifest-path ~/src/fastboop/Cargo.toml

sudo mkosi -f --profile erofs-lz4,phosh,embedded-firmware,precompile-akmods,ostree
BOOT_PROFILE_CLI=~/src/fastboop/target/release/fastboop-cli \
BOOT_PROFILE_ENABLE_PUBLISH=0 \
BOOT_PROFILE_SOURCE_FILE=./mkosi.output/live-pocket-fedora.ero \
./scripts/bootprofile-channel.sh
```

## Local publish test

```bash
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export BOOT_PROFILE_BUCKET=...
export BOOT_PROFILE_ENDPOINT_URL=...
export BOOT_PROFILE_PUBLIC_BASE_URL=https://bleeding.fastboop.win
export BOOT_PROFILE_ENABLE_PUBLISH=1
export BOOT_PROFILE_SOURCE_CASYNC_INDEX=https://bleeding.fastboop.win/live-pocket-fedora/casync/indexes/compose-<build>.caibx
export BOOT_PROFILE_SOURCE_CASYNC_CHUNK_STORE=https://bleeding.fastboop.win/live-pocket-fedora/casync/chunks/
export BOOT_PROFILE_CLI=~/src/fastboop/target/release/fastboop-cli
./scripts/bootprofile-channel.sh
```
