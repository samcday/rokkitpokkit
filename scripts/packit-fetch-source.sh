#!/usr/bin/env bash
set -euo pipefail

specfile="${1:?spec file path is required}"
specdir="$(dirname "$specfile")"

source0="$(rpmspec -P "$specfile" | sed -n 's/^Source0:[[:space:]]*//p' | head -n1)"

if [[ -z "$source0" ]]; then
    echo "Could not resolve Source0 in ${specfile}" >&2
    exit 1
fi

archive_name="${source0##*/}"
archive_path="${specdir}/${archive_name}"

if [[ ! -f "$archive_path" ]]; then
    curl --location --fail --silent --show-error --output "$archive_path" "$source0"
fi

printf '%s\n' "$archive_path"
