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

if [[ "$ERO" == /* ]]; then
    ERO_REF="$ERO"
else
    ERO_REF="./${ERO#./}"
fi

DIGEST="sha512:$(sha512sum "$ERO" | cut -d' ' -f1)"
SIZE_BYTES="$(stat -c '%s' "$ERO")"

MANIFEST="$(mktemp "${TMPDIR:-/tmp}/bootprofile-XXXXXX.json")"
trap 'rm -f "$MANIFEST"' EXIT

python3 - "$MANIFEST" "$ERO_REF" "$DIGEST" "$SIZE_BYTES" <<'PY'
import json
import sys

manifest_path, source_file, digest, size_bytes = sys.argv[1:5]

# UDC-any% list formerly carried by upstream DevPro stage0.kernel_modules.
stage0_kernel_modules = [
    "qcom-apcs-ipc-mailbox",
    "qcom_hwspinlock",
    "smem",
    "qcom_smd",
    "smd-rpm",
    "rpm-proc",
    "qcom-spmi-pmic",
    "qcom_spmi-regulator",
    "qcom_smd-regulator",
    "ulpi",
    "phy-qcom-usb-hs",
    "extcon-usb-gpio",
    "ci_hdrc_msm",
    "dwc3",
    "dwc3-qcom",
    "dwc3-qcom-legacy",
    "phy-qcom-qusb2",
    "nvmem_qfprom",
    "i2c-qcom-geni",
    "pinctrl-sdm845",
    "gcc-sdm845",
    "qnoc-sdm845",
    "gpucc-sdm845",
]

manifest = {
    "id": "rokkitpokkit-local",
    "display_name": "rokkitpokkit (local)",
    # Keep SELinux disabled while Anaconda has a long tail of live-installer breakages.
    "extra_cmdline": "enforcing=0 init_on_alloc=0 fw_devlink=permissive deferred_probe_timeout=60",
    "stage0": {
        "kernel_modules": stage0_kernel_modules,
    },
    "rootfs": {
        "ostree": {
            "erofs": {
                "file": source_file,
                "content": {
                    "digest": digest,
                    "size_bytes": int(size_bytes),
                },
            },
        },
    },
}

with open(manifest_path, "w", encoding="utf-8") as f:
    json.dump(manifest, f, indent=2, sort_keys=True)
    f.write("\n")
PY

fastboop bootprofile create "$MANIFEST" -o "$OUTPUT" --optimize --local-artifact "$ERO_REF"

echo "$OUTPUT (from $ERO)"
echo "  fastboop boot $OUTPUT --local-artifact $ERO_REF"
