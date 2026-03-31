#!/usr/bin/env bash
set -euo pipefail

# Produce a local fastboop channel from a mkosi-built .ero image.
#
# Usage:
#   ./scripts/local-channel.sh                           # auto-detect .ero in mkosi.output/
#   ./scripts/local-channel.sh mkosi.output/ostree.ero   # explicit path
#
# Then boot with:
#   fastboop boot mkosi.output/local.bootpro --local-artifact mkosi.output/ostree.ero

ERO="${1:-}"
OUTPUT="${LOCAL_CHANNEL_OUTPUT:-mkosi.output/local.bootpro}"

if [[ -z "$ERO" ]]; then
    for candidate in mkosi.output/rokkitpokkit.ero mkosi.output/ostree.ero mkosi.output/image.ero; do
        if [[ -f "$candidate" ]]; then
            ERO="$candidate"
            break
        fi
    done
fi

if [[ -z "$ERO" ]]; then
    shopt -s nullglob
    ero_files=(mkosi.output/*.ero)
    shopt -u nullglob
    if [[ ${#ero_files[@]} -eq 1 ]]; then
        ERO="${ero_files[0]}"
    elif [[ ${#ero_files[@]} -gt 1 ]]; then
        echo "multiple .ero files found; pass one explicitly" >&2
        exit 1
    else
        echo "no .ero found in mkosi.output/" >&2
        exit 1
    fi
fi

if [[ ! -f "$ERO" ]]; then
    echo "not found: $ERO" >&2
    exit 1
fi

DIGEST="sha512:$(sha512sum "$ERO" | cut -d' ' -f1)"
SIZE_BYTES="$(stat -c '%s' "$ERO")"

MANIFEST="$(mktemp "${TMPDIR:-/tmp}/bootprofile-XXXXXX.json")"
trap 'rm -f "$MANIFEST"' EXIT

cat > "$MANIFEST" <<EOF
{
  "id": "rokkitpokkit-local",
  "display_name": "rokkitpokkit (local)",
  "extra_cmdline": "selinux=0 init_on_alloc=0 fw_devlink=permissive deferred_probe_timeout=60",
  "rootfs": {
    "ostree": {
      "erofs": {
        "file": "./$ERO",
        "content": {
          "digest": "$DIGEST",
          "size_bytes": $SIZE_BYTES
        }
      }
    }
  }
}
EOF

fastboop bootprofile create "$MANIFEST" -o "$OUTPUT" --optimize --local-artifact "./$ERO"

echo "$OUTPUT (from $ERO)"
echo "  fastboop boot $OUTPUT --local-artifact ./$ERO"
