#!/usr/bin/env python3

import argparse
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlsplit


def run_capture(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, check=False, capture_output=True, text=True)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Download Source0 from spec and print local archive path."
    )
    parser.add_argument("specfile", help="Path to RPM spec file")
    args = parser.parse_args()

    specfile = Path(args.specfile)
    if not specfile.is_file():
        print(f"Spec file not found: {specfile}", file=sys.stderr)
        return 2

    parsed_spec = run_capture(["rpmspec", "-P", str(specfile)])
    if parsed_spec.returncode != 0:
        print(parsed_spec.stdout, end="", file=sys.stderr)
        print(parsed_spec.stderr, end="", file=sys.stderr)
        return parsed_spec.returncode

    source0 = None
    source_pattern = re.compile(r"^Source0?\s*:\s*(\S+)")
    for line in parsed_spec.stdout.splitlines():
        match = source_pattern.match(line.strip())
        if match:
            source0 = match.group(1)
            break

    if source0 is None:
        print(f"Could not resolve Source0 for {specfile}", file=sys.stderr)
        return 1
    source_name = Path(urlsplit(source0).path).name
    if not source_name:
        print(f"Could not determine source filename from Source0: {source0}", file=sys.stderr)
        return 1

    spec_dir = specfile.parent
    fetch = run_capture(["spectool", "-g", "--directory", str(spec_dir), str(specfile)])
    if fetch.returncode != 0:
        print(fetch.stdout, end="", file=sys.stderr)
        print(fetch.stderr, end="", file=sys.stderr)
        return fetch.returncode

    archive_path = spec_dir / source_name
    if not archive_path.is_file():
        print(f"Downloaded source not found at expected path: {archive_path}", file=sys.stderr)
        return 1

    print(archive_path.as_posix())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
