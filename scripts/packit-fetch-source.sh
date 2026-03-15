#!/usr/bin/env bash
set -euo pipefail

specfile="${1:?spec file path is required}"
specdir="$(dirname "$specfile")"

spectool -g --directory "$specdir" "$specfile" >/dev/null

source0="$(rpmspec -P "$specfile" | sed -n 's/^Source0:[[:space:]]*//p' | head -n1)"

if [[ -z "$source0" ]]; then
    echo "Could not resolve Source0 in ${specfile}" >&2
    exit 1
fi

archive_name="${source0##*/}"
archive_path="${specdir}/${archive_name}"

if [[ ! -f "$archive_path" ]]; then
    echo "Downloaded source not found at ${archive_path}" >&2
    exit 1
fi

printf '%s\n' "$archive_path"
