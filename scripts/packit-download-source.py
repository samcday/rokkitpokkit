#!/usr/bin/env python3

import argparse
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlsplit


KNOWN_GITHUB_REPOS = {
    "anaconda": "rhinstaller/anaconda",
    "anaconda-webui": "rhinstaller/anaconda-webui",
}


def run_capture(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, check=False, capture_output=True, text=True)


def parse_spec_fields(specfile: Path) -> dict[str, str | None]:
    parsed_spec = run_capture(["rpmspec", "-P", str(specfile)])
    if parsed_spec.returncode != 0:
        print(parsed_spec.stdout, end="", file=sys.stderr)
        print(parsed_spec.stderr, end="", file=sys.stderr)
        raise RuntimeError("Could not parse spec file")

    fields: dict[str, str | None] = {
        "name": None,
        "version": None,
        "url": None,
        "source0": None,
    }
    patterns = {
        "name": re.compile(r"^Name\s*:\s*(\S+)"),
        "version": re.compile(r"^Version\s*:\s*(\S+)"),
        "url": re.compile(r"^URL\s*:\s*(\S+)"),
        "source0": re.compile(r"^Source0?\s*:\s*(\S+)"),
    }

    for line in parsed_spec.stdout.splitlines():
        stripped = line.strip()
        for field, pattern in patterns.items():
            if fields[field] is None:
                match = pattern.match(stripped)
                if match:
                    fields[field] = match.group(1)

    return fields


def fetch_with_spectool(specfile: Path, spec_dir: Path) -> int:
    fetch = run_capture(["spectool", "-g", "--force", "--directory", str(spec_dir), str(specfile)])
    if fetch.returncode != 0:
        print(fetch.stdout, end="", file=sys.stderr)
        print(fetch.stderr, end="", file=sys.stderr)
    return fetch.returncode


def try_github_release_download(
    spec_dir: Path,
    source_name: str,
    package_name: str | None,
    version: str | None,
    project_url: str | None,
) -> list[str]:
    owner = None
    repo = None

    if project_url:
        parsed_url = urlsplit(project_url)
        if parsed_url.scheme in {"http", "https"} and parsed_url.hostname in {
            "github.com",
            "www.github.com",
        }:
            path_parts = [part for part in parsed_url.path.split("/") if part]
            if len(path_parts) >= 2:
                owner, repo = path_parts[0], path_parts[1]

    if (owner is None or repo is None) and package_name in KNOWN_GITHUB_REPOS:
        owner, repo = KNOWN_GITHUB_REPOS[package_name].split("/", 1)

    if owner is None or repo is None:
        return []

    candidate_tags: list[str] = []
    if package_name and version:
        candidate_tags.append(f"{package_name}-{version}")
    if version:
        candidate_tags.append(version)

    candidate_tags = list(dict.fromkeys(candidate_tags))
    archive_path = spec_dir / source_name
    tried_urls: list[str] = []

    for tag in candidate_tags:
        source_url = (
            f"https://github.com/{owner}/{repo}/releases/download/{tag}/{source_name}"
        )
        tried_urls.append(source_url)
        download = run_capture(
            [
                "curl",
                "-fsSL",
                "--retry",
                "3",
                "--retry-delay",
                "1",
                "--output",
                str(archive_path),
                source_url,
            ]
        )
        if download.returncode == 0 and archive_path.is_file():
            return tried_urls

    return tried_urls


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

    try:
        fields = parse_spec_fields(specfile)
    except RuntimeError:
        return 1

    source0 = fields["source0"]

    if source0 is None:
        print(f"Could not resolve Source0 for {specfile}", file=sys.stderr)
        return 1
    source_name = Path(urlsplit(source0).path).name
    if not source_name:
        print(f"Could not determine source filename from Source0: {source0}", file=sys.stderr)
        return 1

    spec_dir = specfile.parent

    archive_path = spec_dir / source_name
    if archive_path.is_file():
        print(archive_path.as_posix())
        return 0

    if fetch_with_spectool(specfile, spec_dir) != 0:
        return 1

    if archive_path.is_file():
        print(archive_path.as_posix())
        return 0

    tried_urls = try_github_release_download(
        spec_dir=spec_dir,
        source_name=source_name,
        package_name=fields["name"],
        version=fields["version"],
        project_url=fields["url"],
    )

    if not archive_path.is_file():
        if tried_urls:
            print(
                "Downloaded source not found at expected path: "
                f"{archive_path}; attempted URLs: {', '.join(tried_urls)}",
                file=sys.stderr,
            )
        else:
            print(f"Downloaded source not found at expected path: {archive_path}", file=sys.stderr)
        return 1

    print(archive_path.as_posix())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
