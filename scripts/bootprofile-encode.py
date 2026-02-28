#!/usr/bin/env python3

from __future__ import annotations

import argparse
from pathlib import Path


BOOT_PROFILE_BIN_MAGIC = b"FBOOPROF"
BOOT_PROFILE_BIN_FORMAT_VERSION = 1


def encode_uvarint(value: int) -> bytes:
    if value < 0:
        raise ValueError("uvarint cannot encode negative values")

    out = bytearray()
    while True:
        chunk = value & 0x7F
        value >>= 7
        if value:
            out.append(chunk | 0x80)
        else:
            out.append(chunk)
            return bytes(out)


def encode_bytes(value: bytes) -> bytes:
    return encode_uvarint(len(value)) + value


def encode_string(value: str) -> bytes:
    return encode_bytes(value.encode("utf-8"))


def encode_option_string(value: str | None) -> bytes:
    if value is None:
        return encode_uvarint(0)
    return encode_uvarint(1) + encode_string(value)


def encode_stage0() -> bytes:
    # BootProfileStage0Bin {
    #   extra_modules: Vec<String>,
    #   devices: BTreeMap<String, BootProfileDeviceBin>,
    # }
    return encode_uvarint(0) + encode_uvarint(0)


def encode_artifact_source(source_kind: str, source_value: str, source_chunk_store: str | None) -> bytes:
    if source_kind == "casync":
        # BootProfileArtifactSourceBin::Casync {
        #   index: String,
        #   chunk_store: Option<String>,
        # }
        return (
            encode_uvarint(0)
            + encode_string(source_value)
            + encode_option_string(source_chunk_store)
        )

    if source_kind == "file":
        # BootProfileArtifactSourceBin::File { path: String }
        return encode_uvarint(6) + encode_string(source_value)

    raise ValueError(f"unsupported source kind: {source_kind}")


def encode_rootfs(source_kind: str, source_value: str, source_chunk_store: str | None) -> bytes:
    source = encode_artifact_source(source_kind, source_value, source_chunk_store)

    # BootProfileRootfsFilesystemBin::Erofs { source: BootProfileArtifactSourceBin }
    rootfs_filesystem = encode_uvarint(0) + source

    # BootProfileRootfsBin::Ostree { source: BootProfileRootfsFilesystemBin }
    return encode_uvarint(0) + rootfs_filesystem


def encode_boot_profile(
    profile_id: str,
    display_name: str,
    source_kind: str,
    source_value: str,
    source_chunk_store: str | None,
) -> bytes:
    payload = b"".join(
        [
            encode_string(profile_id),
            encode_option_string(display_name),
            encode_rootfs(source_kind, source_value, source_chunk_store),
            encode_uvarint(0),  # kernel: None
            encode_uvarint(0),  # dtbs: None
            encode_uvarint(0),  # dt_overlays: empty
            encode_uvarint(0),  # extra_cmdline: None
            encode_stage0(),
        ]
    )

    return (
        BOOT_PROFILE_BIN_MAGIC
        + BOOT_PROFILE_BIN_FORMAT_VERSION.to_bytes(2, "little")
        + payload
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Encode a minimal fastboop boot profile binary")
    parser.add_argument("--id", required=True, help="Boot profile id")
    parser.add_argument("--display-name", required=True, help="Boot profile display_name")
    parser.add_argument(
        "--source-kind",
        choices=["file", "casync"],
        required=True,
        help="Rootfs artifact source kind",
    )
    parser.add_argument("--source-value", required=True, help="Rootfs source path or index URL")
    parser.add_argument(
        "--source-chunk-store",
        default="",
        help="Optional casync chunk_store URL",
    )
    parser.add_argument("--output", required=True, help="Output .bootpro path")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    chunk_store = args.source_chunk_store.strip() or None
    encoded = encode_boot_profile(
        profile_id=args.id,
        display_name=args.display_name,
        source_kind=args.source_kind,
        source_value=args.source_value,
        source_chunk_store=chunk_store,
    )
    output_path.write_bytes(encoded)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
