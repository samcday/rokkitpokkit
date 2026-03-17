#!/usr/bin/env bash
set -euo pipefail

OUTPUT_DIR="${BOOT_PROFILE_OUTPUT_DIR:-mkosi.output/bootprofile}"
BOOT_PROFILE_BASENAME="${BOOT_PROFILE_BASENAME:-rokkitpokkit}"
BOOT_PROFILE_ID="${BOOT_PROFILE_ID:-${BOOT_PROFILE_BASENAME}}"
BOOT_PROFILE_DISPLAY_NAME="${BOOT_PROFILE_DISPLAY_NAME:-${BOOT_PROFILE_ID}}"
BOOT_PROFILE_MANIFEST_PATH="${OUTPUT_DIR}/${BOOT_PROFILE_BASENAME}.bootpro.json"
BOOT_PROFILE_PATH="${OUTPUT_DIR}/${BOOT_PROFILE_BASENAME}.bootpro"
BOOT_PROFILE_SHA256_PATH="${OUTPUT_DIR}/${BOOT_PROFILE_BASENAME}.bootpro.sha256"
BOOT_PROFILE_CLI="${BOOT_PROFILE_CLI:-fastboop-cli}"

SOURCE_FILE_OVERRIDE="${BOOT_PROFILE_SOURCE_FILE:-}"
SOURCE_CASYNC_INDEX="${BOOT_PROFILE_SOURCE_CASYNC_INDEX:-}"
SOURCE_CASYNC_CHUNK_STORE="${BOOT_PROFILE_SOURCE_CASYNC_CHUNK_STORE:-}"

OBJECT_PREFIX="${BOOT_PROFILE_OBJECT_PREFIX:-rokkitpokkit}"
BOOT_PROFILE_PREFIX="${BOOT_PROFILE_PREFIX:-${OBJECT_PREFIX}/bootprofiles}"
STABLE_POINTER_KEY="${BOOT_PROFILE_STABLE_POINTER_KEY:-${OBJECT_PREFIX}/channels/stable.bootpro}"

PUBLIC_BASE_URL="${BOOT_PROFILE_PUBLIC_BASE_URL:-https://bleeding.fastboop.win}"
ENABLE_PUBLISH_RAW="${BOOT_PROFILE_ENABLE_PUBLISH:-0}"
BUCKET="${BOOT_PROFILE_BUCKET:-}"
ENDPOINT_URL="${BOOT_PROFILE_ENDPOINT_URL:-${R2_ENDPOINT_URL:-}}"

EVENT_NAME="${GITHUB_EVENT_NAME:-local}"
RUN_ID="${GITHUB_RUN_ID:-0}"
RUN_ATTEMPT="${GITHUB_RUN_ATTEMPT:-0}"

if [[ -n "${GITHUB_SHA:-}" ]]; then
    COMMIT_SHA="${GITHUB_SHA}"
else
    COMMIT_SHA="$(git rev-parse HEAD 2>/dev/null || printf 'unknown')"
fi

SHORT_SHA="${COMMIT_SHA:0:12}"
BUILD_ID="${RUN_ID}-${RUN_ATTEMPT}-${SHORT_SHA}"

to_bool() {
    case "${1}" in
        1|true|TRUE|yes|YES|on|ON)
            printf '1'
            ;;
        *)
            printf '0'
            ;;
    esac
}

url_join() {
    local base="$1"
    local suffix="$2"
    base="${base%/}"
    suffix="${suffix#/}"
    printf '%s/%s' "$base" "$suffix"
}

resolve_source_file() {
    local override="${SOURCE_FILE_OVERRIDE}"
    local candidate=""
    local ero_files=()

    if [[ -n "${override}" ]]; then
        if [[ -f "${override}" ]]; then
            printf '%s\n' "${override}"
            return 0
        fi

        echo "missing boot profile source file: ${override}" >&2
        return 1
    fi

    for candidate in "mkosi.output/rokkitpokkit.ero" "mkosi.output/image.ero"; do
        if [[ -f "${candidate}" ]]; then
            printf '%s\n' "${candidate}"
            return 0
        fi
    done

    shopt -s nullglob
    ero_files=(mkosi.output/*.ero)
    shopt -u nullglob

    if [[ "${#ero_files[@]}" -eq 1 ]]; then
        printf '%s\n' "${ero_files[0]}"
        return 0
    fi

    if [[ "${#ero_files[@]}" -gt 1 ]]; then
        echo "multiple erofs images found in mkosi.output; set BOOT_PROFILE_SOURCE_FILE" >&2
        return 1
    fi

    echo "missing boot profile source file: expected mkosi.output/rokkitpokkit.ero or mkosi.output/image.ero" >&2
    return 1
}

mkdir -p "${OUTPUT_DIR}"

SOURCE_KIND=""
SOURCE_VALUE=""
SOURCE_CHUNK_STORE=""

if [[ -n "${SOURCE_CASYNC_INDEX//[[:space:]]/}" ]]; then
    SOURCE_KIND="casync"
    SOURCE_VALUE="${SOURCE_CASYNC_INDEX}"
    SOURCE_CHUNK_STORE="${SOURCE_CASYNC_CHUNK_STORE}"
else
    if ! SOURCE_FILE="$(resolve_source_file)"; then
        exit 1
    fi

    SOURCE_KIND="file"
    if [[ "${SOURCE_FILE}" == /* ]]; then
        SOURCE_VALUE="${SOURCE_FILE}"
    else
        SOURCE_VALUE="./${SOURCE_FILE#./}"
    fi
fi

python3 - "${BOOT_PROFILE_MANIFEST_PATH}" "${BOOT_PROFILE_ID}" "${BOOT_PROFILE_DISPLAY_NAME}" "${SOURCE_KIND}" "${SOURCE_VALUE}" "${SOURCE_CHUNK_STORE}" <<'PY'
import json
import sys

manifest_path, profile_id, display_name, source_kind, source_value, source_chunk_store = sys.argv[1:7]

if source_kind == "casync":
    casync = {"index": source_value}
    if source_chunk_store:
        casync["chunk_store"] = source_chunk_store
    source = {"casync": casync}
elif source_kind == "file":
    source = {"file": source_value}
else:
    raise SystemExit(f"unsupported boot profile source kind: {source_kind}")

manifest = {
    "id": profile_id,
    "display_name": display_name,
    "extra_cmdline": "selinux=0 init_on_alloc=0 fw_devlink=permissive deferred_probe_timeout=60",
    "rootfs": {
        "ostree": {
            "erofs": source,
        }
    },
}

with open(manifest_path, "w", encoding="utf-8") as f:
    json.dump(manifest, f, indent=2, sort_keys=True)
    f.write("\n")
PY

if [[ "${BOOT_PROFILE_CLI}" == */* ]]; then
    if [[ ! -x "${BOOT_PROFILE_CLI}" ]]; then
        echo "missing boot profile CLI executable: ${BOOT_PROFILE_CLI}; set BOOT_PROFILE_CLI to a fastboop-cli binary" >&2
        exit 1
    fi
elif ! command -v "${BOOT_PROFILE_CLI}" >/dev/null 2>&1; then
    echo "missing boot profile CLI command: ${BOOT_PROFILE_CLI}; set BOOT_PROFILE_CLI to a fastboop-cli binary" >&2
    exit 1
fi

"${BOOT_PROFILE_CLI}" bootprofile create "${BOOT_PROFILE_MANIFEST_PATH}" --output "${BOOT_PROFILE_PATH}"

BOOT_PROFILE_SHA256="$(sha256sum "${BOOT_PROFILE_PATH}" | cut -d' ' -f1)"
BOOT_PROFILE_BYTES="$(stat -c '%s' "${BOOT_PROFILE_PATH}")"
printf '%s\n' "${BOOT_PROFILE_SHA256}" > "${BOOT_PROFILE_SHA256_PATH}"

BOOT_PROFILE_KEY="${BOOT_PROFILE_PREFIX}/${BUILD_ID}.bootpro"
BOOT_PROFILE_S3_COORD=""
BOOT_PROFILE_PUBLIC_URL=""
STABLE_POINTER_URL=""

if [[ -n "${BUCKET}" ]]; then
    BOOT_PROFILE_S3_COORD="s3://${BUCKET}/${BOOT_PROFILE_KEY}"
fi

if [[ -n "${PUBLIC_BASE_URL}" ]]; then
    BOOT_PROFILE_PUBLIC_URL="$(url_join "${PUBLIC_BASE_URL}" "${BOOT_PROFILE_KEY}")"
    STABLE_POINTER_URL="$(url_join "${PUBLIC_BASE_URL}" "${STABLE_POINTER_KEY}")"
fi

ENABLE_PUBLISH="$(to_bool "${ENABLE_PUBLISH_RAW}")"

if [[ "${ENABLE_PUBLISH}" == "1" ]]; then
    if [[ -z "${BUCKET}" || -z "${ENDPOINT_URL}" || -z "${AWS_ACCESS_KEY_ID:-}" || -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
        echo "boot profile publish requested but storage credentials/configuration are incomplete; publish disabled" >&2
        ENABLE_PUBLISH="0"
    fi
fi

UPDATE_STABLE_POINTER="0"
if [[ "${EVENT_NAME}" == "push" && "${GITHUB_REF:-}" == "refs/heads/main" ]]; then
    UPDATE_STABLE_POINTER="1"
fi

STABLE_POINTER_UPDATED="0"

if [[ "${ENABLE_PUBLISH}" == "1" ]]; then
    aws s3 cp "${BOOT_PROFILE_PATH}" "s3://${BUCKET}/${BOOT_PROFILE_KEY}" \
        --endpoint-url "${ENDPOINT_URL}" \
        --content-type application/octet-stream \
        --only-show-errors

    if [[ "${UPDATE_STABLE_POINTER}" == "1" ]]; then
        aws s3 cp "${BOOT_PROFILE_PATH}" "s3://${BUCKET}/${STABLE_POINTER_KEY}" \
            --endpoint-url "${ENDPOINT_URL}" \
            --cache-control "no-store, max-age=0" \
            --content-type application/octet-stream \
            --only-show-errors
        STABLE_POINTER_UPDATED="1"
    fi
fi

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    {
        echo "### boot profile channel"
        echo ""
        echo "- Build ID: \`${BUILD_ID}\`"
        echo "- Source: ${SOURCE_KIND} (${SOURCE_VALUE})"
        echo "- Boot profile sha256: \`${BOOT_PROFILE_SHA256}\`"
        echo "- Publish enabled: ${ENABLE_PUBLISH}"
        if [[ -n "${BOOT_PROFILE_S3_COORD}" ]]; then
            echo "- Boot profile: \`${BOOT_PROFILE_S3_COORD}\`"
        fi
        if [[ "${STABLE_POINTER_UPDATED}" == "1" && -n "${STABLE_POINTER_URL}" ]]; then
            echo "- Stable pointer: \`${STABLE_POINTER_URL}\`"
        fi
    } >> "${GITHUB_STEP_SUMMARY}"
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    {
        echo "boot_profile_manifest_path=${BOOT_PROFILE_MANIFEST_PATH}"
        echo "boot_profile_path=${BOOT_PROFILE_PATH}"
        echo "boot_profile_sha256=${BOOT_PROFILE_SHA256}"
        echo "boot_profile_size_bytes=${BOOT_PROFILE_BYTES}"
        echo "boot_profile_source_kind=${SOURCE_KIND}"
        echo "boot_profile_source_value=${SOURCE_VALUE}"
        echo "boot_profile_source_chunk_store=${SOURCE_CHUNK_STORE}"
        echo "boot_profile_key=${BOOT_PROFILE_KEY}"
        echo "boot_profile_s3=${BOOT_PROFILE_S3_COORD}"
        echo "boot_profile_url=${BOOT_PROFILE_PUBLIC_URL}"
        echo "boot_profile_stable_pointer_key=${STABLE_POINTER_KEY}"
        echo "boot_profile_stable_pointer_url=${STABLE_POINTER_URL}"
        echo "boot_profile_stable_pointer_updated=${STABLE_POINTER_UPDATED}"
        echo "boot_profile_publish_enabled=${ENABLE_PUBLISH}"
    } >> "${GITHUB_OUTPUT}"
fi
